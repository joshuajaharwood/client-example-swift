import WebRTC
import LiveKit
import Vision
import CoreImage.CIFilterBuiltins

#if !os(macOS)
public extension UIImage {
    func toCIImage() -> CIImage? {
        if let ciImage = self.ciImage {
            return ciImage
        }
        if let cgImage = self.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }
}
#endif

@available(iOS 15, macOS 12, *)
class BackgroundSwapper {

    lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let r = VNGeneratePersonSegmentationRequest()
        r.qualityLevel = .balanced
        r.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return r
    }()

    lazy var requestHandler = VNSequenceRequestHandler()

    // the image used for background, if nil bg will not be swapped
    var image: CIImage?

    private(set) var busy: Bool = false

    func process(frame: RTCVideoFrame, capture: CaptureFunc) {

        guard !busy else {
            print("Already busy, dropping this frame...")
            return
        }

        busy = true
        defer { busy = false }

        guard let image = image else {
            // if image is nil (no bg swapping), simply use the input frame
            capture(frame)
            return
        }

        let copiedImage = image.copy() as! CIImage

        guard let pixelBuffer = (frame.buffer as? RTCCVPixelBuffer)?.pixelBuffer else {
            // buffer is not a RTCCVPixelBuffer
            capture(frame)
            return
        }

        do {
            try self.requestHandler.perform([segmentationRequest], on: pixelBuffer)
        } catch let error {
            // failed to create background mask
            print("VNSequenceRequestHandler failed with \(error)")
            return
        }

        // Get the pixel buffer that contains the mask image.
        guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
            return
        }

        guard let resultPixelBuffer = blend(original: pixelBuffer,
                                            mask: maskPixelBuffer,
                                            image: copiedImage) else {
            return
        }

        let newFrame = resultPixelBuffer.toRTCVideoFrame(timeStampNs: frame.timeStampNs)
        capture(newFrame)
    }

    // Performs the blend operation.
    func blend(original framePixelBuffer: CVPixelBuffer,
               mask maskPixelBuffer: CVPixelBuffer,
               image: CIImage) -> CVPixelBuffer? {

        // Create CIImage objects for the video frame and the segmentation mask.
        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer)// .oriented(.right)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Scale the mask image to fit the bounds of the video frame.
        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))

        // Scale the bg image to fit the bounds of the video frame.
        let maxExtent = max(originalImage.extent.width, originalImage.extent.height)
        let scaleX2 = maxExtent / image.extent.width
        let scaleY2 = maxExtent / image.extent.height
        let bgImage = image.transformed(by: .init(scaleX: scaleX2, y: scaleY2))

        // Blend the original, background, and mask images.
        let blendFilter = CIFilter.blendWithRedMask()
        blendFilter.inputImage = originalImage
        blendFilter.backgroundImage = bgImage
        blendFilter.maskImage = maskImage

        return blendFilter.outputImage?.toPixelBuffer()
    }
}
