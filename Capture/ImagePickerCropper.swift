import SwiftUI
import PhotosUI

// MARK: - Image Picker and Cropper
//
// This implementation provides a modern image picker and cropper based on the method
// outlined in the Medium article: https://medium.com/@thibault.giraudon/cropping-image-inswiftui-3214900f8666
//
// Key improvements over the previous implementation:
// 1. Uses PhotosPicker for better iOS integration
// 2. Simplified cropping logic with better coordinate calculations
// 3. More reliable image processing
// 4. Better user experience with clear visual feedback
// 5. Proper gesture handling for zoom and pan

struct ImagePickerCropper: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCropper = false
    @State private var imageToCrop: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Image")
                    .font(.title2)
                    .fontWeight(.bold)
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Choose from Photo Library")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Select and crop your image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        imageToCrop = image
                        showingCropper = true
                    }
                }
            }
            .sheet(isPresented: $showingCropper) {
                if let image = imageToCrop {
                    ImageCropperView(image: image) { croppedImage in
                        selectedImage = croppedImage
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Improved Image Cropper View

struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var lastScale: CGFloat = 1.0
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        // Image container with crop overlay
                        ZStack {
                            // Image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                offset = constrainOffset(newOffset, scale: scale, imageSize: image.size, viewSize: viewSize, cropSize: 300)
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            },
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 1.0), 3.0)
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                            }
                                    )
                                )
                                .onAppear {
                                    viewSize = geometry.size
                                }
                            
                            // Crop overlay
                            CropOverlayView()
                        }
                        .frame(width: 300, height: 300)
                        .clipped()
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let croppedImage = cropImage()
                        onCrop(croppedImage)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func constrainOffset(_ newOffset: CGSize, scale: CGFloat, imageSize: CGSize, viewSize: CGSize, cropSize: CGFloat) -> CGSize {
        let aspectRatio = imageSize.width / imageSize.height
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        // Use the actual container size (300x300) instead of the full view size
        let containerSize: CGFloat = 300
        
        if aspectRatio > 1 {
            displayWidth = containerSize
            displayHeight = containerSize / aspectRatio
        } else {
            displayHeight = containerSize
            displayWidth = containerSize * aspectRatio
        }
        
        let scaledWidth = displayWidth * scale
        let scaledHeight = displayHeight * scale
        
        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)
        
        let constrainedX = max(-maxOffsetX, min(maxOffsetX, newOffset.width))
        let constrainedY = max(-maxOffsetY, min(maxOffsetY, newOffset.height))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
    
    private func cropImage() -> UIImage {
        
        let outputSize = CGSize(width: 400, height: 400)
        
        UIGraphicsBeginImageContextWithOptions(outputSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // The image is constrained to a 300x300 container, so we need to use that as our reference
        let containerSize: CGFloat = 300
        let imageAspectRatio = image.size.width / image.size.height
        
        // Calculate how the image is displayed within the 300x300 container (aspect fit)
        var imageDisplaySize: CGSize
        if imageAspectRatio > 1 {
            // Landscape image
            imageDisplaySize = CGSize(width: containerSize, height: containerSize / imageAspectRatio)
        } else {
            // Portrait image
            imageDisplaySize = CGSize(width: containerSize * imageAspectRatio, height: containerSize)
        }
        
        // Apply the current scale to the display size
        let scaledDisplaySize = CGSize(
            width: imageDisplaySize.width * scale,
            height: imageDisplaySize.height * scale
        )
        
        // Calculate where the image appears within the 300x300 container (centered, then offset)
        let imageViewRect = CGRect(
            x: (containerSize - scaledDisplaySize.width) / 2 + offset.width,
            y: (containerSize - scaledDisplaySize.height) / 2 + offset.height,
            width: scaledDisplaySize.width,
            height: scaledDisplaySize.height
        )
        
        // The crop circle is centered in the 300x300 container
        let cropCenterInContainer = CGPoint(x: containerSize / 2, y: containerSize / 2)
        
        // Calculate the crop center relative to the image view
        let cropCenterRelativeToImageView = CGPoint(
            x: cropCenterInContainer.x - imageViewRect.origin.x,
            y: cropCenterInContainer.y - imageViewRect.origin.y
        )
        
        // Normalize to 0-1 range within the image view
        let normalizedCropCenter = CGPoint(
            x: cropCenterRelativeToImageView.x / imageViewRect.width,
            y: cropCenterRelativeToImageView.y / imageViewRect.height
        )
        
        // Convert to actual image coordinates
        let cropCenterInImage = CGPoint(
            x: normalizedCropCenter.x * image.size.width,
            y: normalizedCropCenter.y * image.size.height
        )
        
        // Calculate the crop radius in image coordinates
        let cropRadiusInImage = (containerSize / 2) * (image.size.width / imageViewRect.width)
        
        // Calculate the source rect in the original image
        var sourceRect = CGRect(
            x: cropCenterInImage.x - cropRadiusInImage,
            y: cropCenterInImage.y - cropRadiusInImage,
            width: cropRadiusInImage * 2,
            height: cropRadiusInImage * 2
        )
        
        // Clamp the source rect to be within the image bounds
        sourceRect = sourceRect.intersection(CGRect(origin: .zero, size: image.size))
        
        
        // Instead of cropping the CGImage (which loses orientation), 
        // we'll draw the full image with a clipping path and transform
        context.saveGState()
        
        // Create a circular clipping path
        let rect = CGRect(origin: .zero, size: outputSize)
        context.addEllipse(in: rect)
        context.clip()
        
        // Calculate the drawing rect to show only the crop area
        // We need to map the crop area from image coordinates to output coordinates
        let cropRect = sourceRect
        
        // Calculate the scale to fit the crop area into the output circle
        let scaleX = outputSize.width / cropRect.width
        let scaleY = outputSize.height / cropRect.height
        let scale = min(scaleX, scaleY)
        
        // Calculate the drawing rect in output coordinates
        let scaledWidth = cropRect.width * scale
        let scaledHeight = cropRect.height * scale
        let offsetX = (outputSize.width - scaledWidth) / 2
        let offsetY = (outputSize.height - scaledHeight) / 2
        
        // Create the drawing rect that will show only the crop area
        let drawingRect = CGRect(
            x: offsetX - (cropRect.origin.x * scale),
            y: offsetY - (cropRect.origin.y * scale),
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // Draw the full image in the calculated rect (this preserves orientation)
        image.draw(in: drawingRect)
        
        context.restoreGState()
        
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
        return result
    }
}

// MARK: - Crop Overlay View

struct CropOverlayView: View {
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.5)
                .allowsHitTesting(false)
            
            // Clear circular crop area
            Circle()
                .fill(Color.clear)
                .frame(width: 300, height: 300)
                .blendMode(.destinationOut)
                .allowsHitTesting(false)
            
            // White border
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 300, height: 300)
                .allowsHitTesting(false)
            
            // Optional: Add corner guides for better visual feedback
            VStack {
                HStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 3)
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 3)
                }
                Spacer()
                HStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 3)
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 3)
                }
            }
            .frame(width: 300, height: 300)
            .allowsHitTesting(false)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    ImagePickerCropper(selectedImage: .constant(nil))
}
