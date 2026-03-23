// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import SwiftUI
import AppKit

// A reusable component that encapsulates styling and hover logic
struct HoverLink: View {
    let title: String
    let urlString: String

    var body: some View {
        // Safely unwrap the URL
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
                    .underline()
            }
            .onHover { isHovered in
                if isHovered {
                    // Push the hand cursor onto the system cursor stack
                    NSCursor.pointingHand.push()
                } else {
                    // Pop it off when the mouse leaves
                    NSCursor.pop()
                }
            }
        }
    }
}

// MARK: - Theme

private enum Theme {
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.87, green: 0.0, blue: 0.87), Color(red: 0.48, green: 0.2, blue: 0.66)],
        startPoint: .leading, endPoint: .trailing
    )
    static let accentColor = Color(red: 0.87, green: 0.0, blue: 0.87)
    static let cardBackground = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.1)
    static let subtleText = Color.white.opacity(0.5)
    static let labelText = Color.white.opacity(0.85)
    static let background = Color(nsColor: NSColor(red: 0.09, green: 0.07, blue: 0.14, alpha: 1.0))
}

// MARK: - ConfigView

struct ConfigView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var isHoveringStart = false
    @State private var showAbout = false

    private let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]

    private var isDirectorySoundMode: Bool {
        viewModel.protectionMode == .fartPrank || viewModel.protectionMode == .customSounds
    }

    private var soundDirectoryTitle: String {
        viewModel.protectionMode == .fartPrank ? "Fart Sounds Directory" : "Custom Sounds Directory"
    }

    private var soundDirectoryIcon: String {
        viewModel.protectionMode == .fartPrank ? "💨" : "🎵"
    }

    private var soundDirectoryPlaceholder: String {
        viewModel.protectionMode == .fartPrank ? "Path to fart .mp3 files…" : "Path to custom .mp3 files…"
    }

    private var soundDirectoryCooldownLabel: String {
        viewModel.protectionMode == .fartPrank ? "sec between farts" : "sec between sounds"
    }

    private var isWebcamPrankMode: Bool {
        viewModel.protectionMode == .webcamPrank
    }

    private var soundDirectoryBinding: Binding<String> {
        Binding(
            get: {
                viewModel.protectionMode == .fartPrank
                    ? viewModel.fartSoundsDirectory
                    : viewModel.customSoundsDirectory
            },
            set: { newValue in
                if viewModel.protectionMode == .fartPrank {
                    viewModel.fartSoundsDirectory = newValue
                } else {
                    viewModel.customSoundsDirectory = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            ScrollView {
                VStack(spacing: 14) {
                    deactivationMethodsCard
                    failsafeCard
                    protectionModeCard
                    if viewModel.protectionMode == .flashAndSound {
                        alertSoundCard
                    }
                    if isDirectorySoundMode {
                        directorySoundsCard
                    }
                    if isWebcamPrankMode {
                        webcamPrankCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            startButton
        }
        .frame(minWidth: 440, maxWidth: 440, minHeight: 520)
        .background(Theme.background)
        .alert("Validation Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.accentColor.opacity(0.4), radius: 16, y: 4)
                if let iconURL = ResourceHelper.url(forResource: "icon-small", withExtension: "png"),
                   let nsImage = NSImage(contentsOf: iconURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text("🔒")
                        .font(.system(size: 28))
                }
            }
            .padding(.top, 24)

            Text("Screen Prank Locker")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Configure your prank lock settings")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.subtleText)
                .padding(.bottom, 4)

            Button {
                showAbout = true
            } label: {
                HStack(spacing: 4) {
                    Text("ℹ️")
                        .font(.system(size: 11))
                    Text("About")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(Theme.subtleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Cards

    private var deactivationMethodsCard: some View {
        ConfigCard(icon: "🔓", title: "Deactivation Methods") {
            VStack(alignment: .leading, spacing: 12) {
                Text("At least one method must be enabled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.subtleText)

                // --- Secret Sequence ---
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $viewModel.isSequenceDeactivationEnabled) {
                        HStack(spacing: 6) {
                            Text("🔑")
                                .font(.system(size: 13))
                            Text("Secret Sequence")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.labelText)
                        }
                    }
                    .toggleStyle(.checkbox)

                    if viewModel.isSequenceDeactivationEnabled {
                        TextField("Type your secret unlock phrase…", text: $viewModel.deactivationSequence)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(10)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // --- Touch ID / Fingerprint ---
                Toggle(isOn: $viewModel.isTouchIDDeactivationEnabled) {
                    HStack(spacing: 6) {
                        Text("👆")
                            .font(.system(size: 13))
                        Text("Touch ID / Fingerprint")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.labelText)
                    }
                }
                .toggleStyle(.checkbox)

                Divider().background(Color.white.opacity(0.08))

                // --- Emergency Hotkey ---
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $viewModel.isEmergencyStopEnabled) {
                        HStack(spacing: 6) {
                            Text("🚨")
                                .font(.system(size: 13))
                            Text("Emergency Hotkey")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.labelText)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.isEmergencyStopEnabled) { isEnabled in
                        if !isEnabled {
                            viewModel.stopRecordingShortcut()
                        }
                    }

                    if viewModel.isEmergencyStopEnabled {
                        Text("Key combo to instantly kill the app during a lock session")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.subtleText)
                        HStack(spacing: 10) {
                            Text(viewModel.emergencyStopShortcut.displayString)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            viewModel.isRecordingShortcut
                                                ? Theme.accentColor
                                                : Color.white.opacity(0.08),
                                            lineWidth: viewModel.isRecordingShortcut ? 2 : 1
                                        )
                                )
                            Button {
                                if viewModel.isRecordingShortcut {
                                    viewModel.stopRecordingShortcut()
                                } else {
                                    viewModel.startRecordingShortcut()
                                }
                            } label: {
                                Text(viewModel.isRecordingShortcut ? "Cancel" : "Record")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.isRecordingShortcut
                                            ? Theme.accentColor.opacity(0.6)
                                            : Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        if viewModel.isRecordingShortcut {
                            Text("Press your desired key combo…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.accentColor)
                        }
                    }
                }
            }
        }
    }

    private var failsafeCard: some View {
        ConfigCard(icon: "⏱", title: "Failsafe Timeout") {
            HStack(spacing: 8) {
                TextField("30", text: $viewModel.failsafeTimeout)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .frame(width: 80)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                Text("minutes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.subtleText)
            }
        }
    }

    private var protectionModeCard: some View {
        ConfigCard(icon: "🛡", title: "Protection Mode") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProtectionModePill(label: "Silent", icon: "🤫", mode: .silent, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .silent
                    }
                    ProtectionModePill(label: "Flash", icon: "⚡", mode: .flash, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .flash
                    }
                    ProtectionModePill(label: "Flash & Sound", icon: "🔊", mode: .flashAndSound, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .flashAndSound
                    }
                }
                HStack(spacing: 8) {
                    ProtectionModePill(label: "Fart 💨", icon: "💩", mode: .fartPrank, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .fartPrank
                    }
                    ProtectionModePill(label: "Custom MP3s", icon: "🎵", mode: .customSounds, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .customSounds
                    }
                    ProtectionModePill(label: "Webcam", icon: "📸", mode: .webcamPrank, selected: viewModel.protectionMode) {
                        viewModel.protectionMode = .webcamPrank
                    }
                }
            }
        }
    }

    private var alertSoundCard: some View {
        ConfigCard(icon: "🔔", title: "Alert Sound") {
            HStack(spacing: 10) {
                Picker("", selection: $viewModel.alertSoundName) {
                    ForEach(systemSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button {
                    if let sound = NSSound(named: NSSound.Name(viewModel.alertSoundName)) {
                        sound.play()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("▶")
                            .font(.system(size: 10))
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Fart Sounds

    private var directorySoundsCard: some View {
        ConfigCard(icon: soundDirectoryIcon, title: soundDirectoryTitle) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(soundDirectoryPlaceholder, text: soundDirectoryBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                HStack(spacing: 8) {
                    Text("Cooldown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.subtleText)
                    TextField("3", text: $viewModel.fartCooldownSeconds)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .frame(width: 60)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    Text(soundDirectoryCooldownLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.subtleText)
                }
                HStack(spacing: 8) {
                    Text("Initial delay")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.subtleText)
                    TextField("0", text: $viewModel.fartInitialDelaySeconds)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .frame(width: 60)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    Text("sec before first sound")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.subtleText)
                }
            }
        }
    }
    private var webcamPrankCard: some View {
        ConfigCard(icon: "📸", title: "Webcam Prank") {
            Text("Telegram bot token and chat ID configuration")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.subtleText)
            TextField("Bot Token", text: $viewModel.telegramBotToken)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            TextField("Chat ID", text: $viewModel.telegramChatID)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )   
        }
    }
    private var startButton: some View {
        Button {
            viewModel.startClicked()
        } label: {
            HStack(spacing: 8) {
                Text("🚀")
                    .font(.system(size: 16))
                Text("Activate Prank Lock")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Theme.accentGradient
                    .opacity(isHoveringStart ? 1.0 : 0.85)
            )
            .cornerRadius(12)
            .shadow(color: Theme.accentColor.opacity(isHoveringStart ? 0.5 : 0.25),
                    radius: isHoveringStart ? 20 : 10, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringStart = hovering
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - About View

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: Theme.accentColor.opacity(0.4), radius: 16, y: 4)
                if let iconURL = ResourceHelper.url(forResource: "icon-small", withExtension: "png"),
                   let nsImage = NSImage(contentsOf: iconURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text("\u{1F512}")
                        .font(.system(size: 36))
                }
            }
            .padding(.top, 24)

            Text("Screen Prank Locker")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Version 1.0.0")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.subtleText)

            Text("A fun prank screen locker for macOS that deters nosy people with flashes, sounds, fart noises, and webcam snapshots.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.labelText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Text("\u{00A9} 2026 Screen Prank Locker")
                .font(.system(size: 11))
                .foregroundColor(Theme.subtleText)

            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    HoverLink(
                        title: "SlashGordon", 
                        urlString: "https://github.com/SlashGordon"
                    )

                    HoverLink(
                        title: "slashgordon.link", 
                        urlString: "https://www.slashgordon.link/"
                    )
                }

                HoverLink(
                    title: "slash.gordon.dev@gmail.com", 
                    urlString: "mailto:slash.gordon.dev@gmail.com"
                )
            }

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Theme.accentGradient)
            .cornerRadius(8)
            .padding(.bottom, 20)
        }
        .frame(width: 320, height: 340)
        .background(Theme.background)
    }
}

// MARK: - Config Card

private struct ConfigCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.labelText)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Protection Mode Pill

private struct ProtectionModePill: View {
    let label: String
    let icon: String
    let mode: ProtectionMode
    let selected: ProtectionMode
    let action: () -> Void

    private var isSelected: Bool { mode == selected }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : Theme.subtleText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(Theme.accentGradient)
                    : AnyShapeStyle(Color.white.opacity(0.06))
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
