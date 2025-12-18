//
//  CreatePostView.swift
//  SocialTen
//

import SwiftUI
import AVFoundation

struct CreatePostView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var startOnPromptTab: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var caption: String = ""
    @State private var promptResponse: String = ""
    @State private var capturedImageData: Data?
    @State private var postType: PostType = .post
    @State private var showCamera = false
    
    enum PostType: String, CaseIterable {
        case post = "post"
        case prompt = "prompt"
    }
    
    var canPost: Bool {
        switch postType {
        case .post:
            // Can post if there's a caption OR a photo
            return !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || capturedImageData != nil
        case .prompt:
            return !promptResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("cancel")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(ShadowTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("new post")
                        .font(.system(size: 16, weight: .light))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: createPost) {
                        Text("post")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(canPost ? .white : ShadowTheme.textTertiary)
                    }
                    .disabled(!canPost)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Type selector (now just Post and Prompt)
                HStack(spacing: 0) {
                    ForEach(PostType.allCases, id: \.self) { type in
                        Button(action: { postType = type }) {
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .tracking(1)
                                .foregroundColor(postType == type ? ShadowTheme.textPrimary : ShadowTheme.textTertiary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    postType == type ?
                                    Color.white.opacity(0.05) : Color.clear
                                )
                        }
                    }
                }
                .background(ShadowTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch postType {
                        case .post:
                            UnifiedPostInput(
                                caption: $caption,
                                capturedImageData: $capturedImageData,
                                showCamera: $showCamera
                            )
                            
                        case .prompt:
                            PromptInput(prompt: viewModel.todaysPrompt, response: $promptResponse)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Full screen camera
            if showCamera {
                SquareCameraView(
                    capturedImageData: $capturedImageData,
                    isPresented: $showCamera
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCamera)
        .onAppear {
            if startOnPromptTab {
                postType = .prompt
            }
        }
    }
    
    func createPost() {
        switch postType {
        case .post:
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.createPost(
                imageData: capturedImageData,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption
            )
        case .prompt:
            viewModel.createPost(imageData: nil, caption: nil, promptResponse: promptResponse)
        }
        dismiss()
    }
}

// MARK: - Unified Post Input (Photo + Caption)

struct UnifiedPostInput: View {
    @Binding var caption: String
    @Binding var capturedImageData: Data?
    @Binding var showCamera: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Photo section
            if let imageData = capturedImageData, let uiImage = UIImage(data: imageData) {
                // Show captured photo
                VStack(spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    HStack(spacing: 16) {
                        Button(action: { showCamera = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .medium))
                                Text("retake")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(1)
                                    .textCase(.uppercase)
                            }
                            .foregroundColor(ShadowTheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        Button(action: { capturedImageData = nil }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                Text("remove")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(1)
                                    .textCase(.uppercase)
                            }
                            .foregroundColor(ShadowTheme.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
            } else {
                // Show add photo button
                Button(action: { showCamera = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                        
                        Text("add photo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ShadowTheme.textSecondary)
                        
                        Spacer()
                        
                        Text("optional")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(ShadowTheme.textTertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ShadowTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
            }
            
            // Caption section
            VStack(alignment: .leading, spacing: 10) {
                Text("caption")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ShadowTheme.textTertiary)
                    .textCase(.uppercase)
                
                TextField("what's on your mind?", text: $caption, axis: .vertical)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
                    .lineLimit(5...10)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ShadowTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .onChange(of: caption) { oldValue, newValue in
                        if newValue.count > 200 {
                            caption = String(newValue.prefix(200))
                        }
                    }
                
                HStack {
                    if capturedImageData == nil {
                        Text("photo or caption required")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(ShadowTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    Text("\(caption.count)/200")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(caption.count >= 180 ? .orange.opacity(0.8) : ShadowTheme.textTertiary)
                }
            }
        }
    }
}

// MARK: - Square Camera View (Option A - Simple)

struct SquareCameraView: View {
    @Binding var capturedImageData: Data?
    @Binding var isPresented: Bool
    
    @State private var previewImage: UIImage?
    @State private var showPreview = false
    @State private var isFlashOn = false
    @State private var isUsingFrontCamera = false
    @State private var photoCaption: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showPreview, let image = previewImage {
                // Preview captured photo with caption option
                PhotoPreviewWithCaption(
                    image: image,
                    caption: $photoCaption,
                    onRetake: {
                        previewImage = nil
                        showPreview = false
                        photoCaption = ""
                    },
                    onUse: {
                        capturedImageData = image.jpegData(compressionQuality: 0.8)
                        isPresented = false
                    }
                )
            } else {
                // Simple square camera
                VStack(spacing: 0) {
                    // Top bar - Close and Flash buttons
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                        
                        Spacer()
                        
                        // Flash toggle
                        Button(action: { isFlashOn.toggle() }) {
                            Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(isFlashOn ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Square camera preview
                    GeometryReader { geo in
                        let size = geo.size.width
                        
                        SquareCameraPreview(
                            isFlashOn: $isFlashOn,
                            isUsingFrontCamera: $isUsingFrontCamera,
                            onCapture: { image in
                                previewImage = image
                                showPreview = true
                            }
                        )
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Bottom controls - Camera flip button
                    HStack {
                        Spacer()
                        
                        Button(action: { isUsingFrontCamera.toggle() }) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

// MARK: - Photo Preview With Caption

struct PhotoPreviewWithCaption: View {
    let image: UIImage
    @Binding var caption: String
    let onRetake: () -> Void
    let onUse: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Close button
                HStack {
                    Button(action: onRetake) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                // Photo
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 30) {
                    Button(action: onRetake) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            
                            Text("retake")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.7))
                                .textCase(.uppercase)
                        }
                    }
                    
                    Button(action: onUse) {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                )
                            
                            Text("use")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.7))
                                .textCase(.uppercase)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Square Camera Preview (UIKit)

struct SquareCameraPreview: UIViewControllerRepresentable {
    @Binding var isFlashOn: Bool
    @Binding var isUsingFrontCamera: Bool
    let onCapture: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> SquareCameraViewController {
        let controller = SquareCameraViewController()
        controller.onCapture = onCapture
        controller.isFlashOn = isFlashOn
        controller.isUsingFrontCamera = isUsingFrontCamera
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SquareCameraViewController, context: Context) {
        if uiViewController.isFlashOn != isFlashOn {
            uiViewController.isFlashOn = isFlashOn
        }
        
        if uiViewController.isUsingFrontCamera != isUsingFrontCamera {
            uiViewController.isUsingFrontCamera = isUsingFrontCamera
            uiViewController.switchCamera()
        }
    }
}

class SquareCameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var isFlashOn: Bool = false
    var isUsingFrontCamera: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureButton: UIButton!
    private var currentCameraInput: AVCaptureDeviceInput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = true
        checkCameraPermission()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showPermissionDenied()
                    }
                }
            }
        default:
            showPermissionDenied()
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showCameraUnavailable()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentCameraInput = input
        }
        
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.photoOutput = output
        self.previewLayer = previewLayer
        
        setupCaptureButton()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func switchCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        if let currentInput = currentCameraInput {
            session.removeInput(currentInput)
        }
        
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentCameraInput = input
        }
        
        session.commitConfiguration()
    }
    
    private func setupCaptureButton() {
        captureButton = UIButton(type: .custom)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        
        let outerRing = UIView()
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        outerRing.backgroundColor = .clear
        outerRing.layer.borderColor = UIColor.white.cgColor
        outerRing.layer.borderWidth = 4
        outerRing.layer.cornerRadius = 35
        outerRing.isUserInteractionEnabled = false
        
        let innerCircle = UIView()
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 28
        innerCircle.isUserInteractionEnabled = false
        
        view.addSubview(captureButton)
        captureButton.addSubview(outerRing)
        captureButton.addSubview(innerCircle)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            outerRing.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 70),
            outerRing.heightAnchor.constraint(equalToConstant: 70),
            
            innerCircle.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 56),
            innerCircle.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
    }
    
    @objc private func capturePhoto() {
        var settings = AVCapturePhotoSettings()
        
        if let device = currentCameraInput?.device, device.hasFlash && device.isFlashAvailable {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    private func showPermissionDenied() {
        let label = UILabel()
        label.text = "Camera access required\nPlease enable in Settings"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func showCameraUnavailable() {
        let label = UILabel()
        label.text = "Camera unavailable"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

// MARK: - Photo Capture Delegate

extension SquareCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        var croppedImage = cropToSquare(image)
        
        if isUsingFrontCamera {
            croppedImage = croppedImage.withHorizontallyFlippedOrientation()
        }
        
        DispatchQueue.main.async {
            self.onCapture?(croppedImage)
        }
    }
    
    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let size = min(width, height)
        
        let x = (width - size) / 2
        let y = (height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Prompt Input

struct PromptInput: View {
    let prompt: DailyPrompt
    @Binding var response: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("today's prompt")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ShadowTheme.textTertiary)
                    .textCase(.uppercase)
                
                Text(prompt.text)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
            }
            
            TextField("", text: $response, axis: .vertical)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(ShadowTheme.textPrimary)
                .lineLimit(3...6)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ShadowTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    CreatePostView()
        .environmentObject(AppViewModel())
}
