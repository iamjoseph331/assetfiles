// Template from 2016 Vectorform LLC
// http://www.vectorform.com/
// https://github.com/CocoaHeadsDetroit/ARKit2DTracking
//
// ARKit2DTracking
// ViewController.swift
//

import UIKit
import SceneKit
import ARKit
import AVFoundation
import Vision

var modelname : String!

class Downloader : NSObject, URLSessionDownloadDelegate {
    
    var url : URL?
    // will be used to do whatever is needed once download is complete
    var obj1 : NSObject?
    
    init(_ obj1 : NSObject)
    {
        self.obj1 = obj1
    }
    
    //is called once the download is complete
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        //copy downloaded data to your documents directory with same names as source file
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationUrl = documentsUrl!.appendingPathComponent(url!.lastPathComponent)
        let dataFromURL = NSData(contentsOf: location)
        dataFromURL?.write(to: destinationUrl, atomically: true)
        print(destinationUrl)
        modelname = url!.lastPathComponent
        //now it is time to do what is needed to be done after the download
        //obj1!.callWhatIsNeeded()
    }
    
    //this is to track progress
    private func URLSession(session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
    }
    
    // if there is an error during download this will be called
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if(error != nil)
        {
            //handle the error
            print("Download completed with error: \(error!.localizedDescription)");
        }
    }
    
    //method to be called to download
    func download(url: URL)
    {
        self.url = url
        
        //download identifier can be customized. I used the "ulr.absoluteString"
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: url.absoluteString)
        let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
    }}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - Properties
    
    @IBOutlet var sceneView: ARSCNView!
    var qrCodeFrameView:UIView?
    var detectedDataAnchor: ARAnchor?
    var processing = false
    var tapped = false
    var lastURL: NSURL!
    
    // MARK: - View Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set the session's delegate
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Set the bounding box for qr code
        qrCodeFrameView = UIView()
        qrCodeFrameView?.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView?.layer.borderWidth = 2
        view.addSubview(qrCodeFrameView!)
        view.bringSubview(toFront: qrCodeFrameView!)
        let TapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleARTap(_:)))
        sceneView.addGestureRecognizer(TapRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable horizontal plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

 
    // MARK: - ARSessionDelegate
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Only run one Vision request at a time
        if self.processing {
            return
        }
        
        self.processing = true
        
        // Create a Barcode Detection Request
        let request = VNDetectBarcodesRequest { (request, error) in
            
            // Get the first result out of the results, if there are any
            if let results = request.results, let result = results.first as? VNBarcodeObservation {
                
                // Get the bounding box for the bar code and find the center
                var rect = result.boundingBox
                
                // Flip coordinates
                rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
                rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
                
                // Get center
                let center = CGPoint(x: rect.midX, y: rect.midY)
                
                // Read the bar code
                if let payload = result.payloadStringValue{
                    //print("payload is \(payload)")
                    let url = NSURL(string: payload)
                   // var desurl: URL!
                    if(url != self.lastURL){
                        Downloader(url! as NSObject).download(url: url! as URL)
                        self.lastURL = url
                    }
                }
                // Go back to the main thread
                DispatchQueue.main.async {
                    // Perform a hit test on the ARFrame to find a surface
                    let hitTestResults = frame.hitTest(center, types: [.featurePoint/*, .estimatedHorizontalPlane, .existingPlane, .existingPlaneUsingExtent*/] )
                    
                    // If we have a result, process it
                    if let hitTestResult = hitTestResults.first {
                        if(self.tapped == true){
                        // If we already have an anchor, update the position of the attached node
                            if let detectedDataAnchor = self.detectedDataAnchor,
                                let node = self.sceneView.node(for: detectedDataAnchor) {
                                
                                    node.transform = SCNMatrix4(hitTestResult.worldTransform)
                                
                            } else {
                                // Create an anchor. The node will be created in delegate methods
                                self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
                                self.sceneView.session.add(anchor: self.detectedDataAnchor!)
                            }
                        }
                    }
                        
                    
                    // Set processing flag off
                    self.processing = false
                }
                
            } else {
                // Set processing flag off
                self.processing = false
            }
        }
        
        // Process the request in the background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Set it to recognize QR code only
                request.symbologies = [.QR]
                
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                options: [:])
                // Process the request
                try imageRequestHandler.perform([request])
            } catch {
                
            }
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    @objc
    func handleARTap(_ gestureRecognize: UITapGestureRecognizer){
        self.tapped = true;
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // If this is our anchor, create a node
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            
            // Load a 3D Model to display
            let wrapperNode = SCNNode()
            let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let str = documentsUrl?.appendingPathComponent(modelname)
            let data = NSData(contentsOf: str!)
            let ModSCN = SCNSceneSource(data: data! as Data)
            let modelscene = ModSCN?.scene()
            let mnode = modelscene?.rootNode
            wrapperNode.addChildNode(mnode!)
            
            // Set its position based off the anchor
            wrapperNode.transform = SCNMatrix4(anchor.transform)
            
            return wrapperNode
        }
        return nil
    }
}
