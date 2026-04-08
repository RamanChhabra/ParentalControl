import DeviceActivity
import Flutter
import UIKit
import SwiftUI
import FamilyControls
import ManagedSettings

private enum ScreenTimeReportConstants {
    static let appGroupId = "group.com.parentalcontrol.application"
    static let usageSecondsKey = "screen_time_usage_seconds_by_key_v1"
    /// Must match `kReportContext` in `ScreenTimeReportExtension.swift`.
    static let reportContext = "parentalcontrol.totalUsage"
}

private let kFamilySelectionDefaultsKey = "ios_screen_time_tools.family_activity_selection"

/// Ensures `FlutterResult` is invoked at most once.
private final class FlutterResultBox {
    private var sent = false
    private let flutterResult: FlutterResult
    private let onComplete: (() -> Void)?

    init(flutterResult: @escaping FlutterResult, onComplete: (() -> Void)? = nil) {
        self.flutterResult = flutterResult
        self.onComplete = onComplete
    }

    func send(_ value: Any?) {
        guard !sent else { return }
        sent = true
        flutterResult(value)
        onComplete?()
    }
}

@available(iOS 16.0, *)
private struct FamilyActivityPickerHost: View {
    @State private var selection: FamilyActivitySelection
    let onCancel: () -> Void
    let onApply: (FamilyActivitySelection) -> Void

    init(
        initialSelection: FamilyActivitySelection,
        onCancel: @escaping () -> Void,
        onApply: @escaping (FamilyActivitySelection) -> Void
    ) {
        _selection = State(initialValue: initialSelection)
        self.onCancel = onCancel
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Apps to limit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onApply(selection) }
                    }
                }
        }
    }
}

@available(iOS 16.0, *)
private final class FamilyPickerPresenter: NSObject, UIAdaptivePresentationControllerDelegate {
    private let resultBox: FlutterResultBox
    private weak var hostingController: UIViewController?

    init(resultBox: FlutterResultBox) {
        self.resultBox = resultBox
    }

    func presentPicker(initial: FamilyActivitySelection, from root: UIViewController) {
        let host = UIHostingController(
            rootView: FamilyActivityPickerHost(
                initialSelection: initial,
                onCancel: { [self] in
                    self.dismissModal(apply: false, selection: nil)
                },
                onApply: { [self] sel in
                    self.dismissModal(apply: true, selection: sel)
                }
            )
        )
        hostingController = host
        host.modalPresentationStyle = .pageSheet
        host.presentationController?.delegate = self
        root.present(host, animated: true)
    }

    private func dismissModal(apply: Bool, selection: FamilyActivitySelection?) {
        guard let host = hostingController else {
            resultBox.send(nil)
            return
        }
        host.dismiss(animated: true) {
            if apply, let selection {
                Self.persistSelection(selection)
                Self.applyShield(selection)
            }
            self.resultBox.send(nil)
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        resultBox.send(nil)
    }

    private static func persistSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: kFamilySelectionDefaultsKey)
        }
    }

    private static func loadSelection() -> FamilyActivitySelection {
        guard let data = UserDefaults.standard.data(forKey: kFamilySelectionDefaultsKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return decoded
    }

    private static func applyShield(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore()
        if selection.applicationTokens.isEmpty {
            store.shield.applications = nil
        } else {
            store.shield.applications = selection.applicationTokens
        }
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if selection.webDomainTokens.isEmpty {
            store.shield.webDomains = nil
        } else {
            store.shield.webDomains = selection.webDomainTokens
        }
    }

    static func loadInitialSelection() -> FamilyActivitySelection {
        loadSelection()
    }

    static func clearShieldAndPersistence() {
        UserDefaults.standard.removeObject(forKey: kFamilySelectionDefaultsKey)
        ManagedSettingsStore().clearAllSettings()
    }
}

@available(iOS 16.0, *)
private struct ScreenTimeReportTriggerView: View {
    let filter: DeviceActivityFilter

    var body: some View {
        DeviceActivityReport(
            DeviceActivityReport.Context(ScreenTimeReportConstants.reportContext),
            filter: filter
        )
        .frame(width: 2, height: 2)
        .opacity(0.02)
    }
}

@available(iOS 15.0, *)
public class SwiftIosScreenTimeToolsPlugin: NSObject, FlutterPlugin {
    /// Keeps the picker presenter alive while the system sheet is visible.
    private var activeFamilyPickerPresenter: FamilyPickerPresenter?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ios_screen_time_tools",
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftIosScreenTimeToolsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestScreenTimePermission":
            requestPermission(result: result)
        case "hasScreenTimePermission":
            checkPermission(result: result)
        case "selectAppsToDiscourage":
            selectAppsToDiscourage(result: result)
        case "encourageAll":
            encourageAll(result: result)
        case "getScreenTimeData":
            getScreenTimeData(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        Task {
            if await Self.isAuthorizationApproved() {
                await MainActor.run { result(true) }
                return
            }
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                await MainActor.run {
                    result(
                        FlutterError(
                            code: "AUTH_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
                return
            }
            let ok = await Self.waitForAuthorizationApproved()
            await MainActor.run { result(ok) }
        }
    }

    private func checkPermission(result: @escaping FlutterResult) {
        Task {
            let ok = await Self.isAuthorizationApproved()
            await MainActor.run { result(ok) }
        }
    }

    private func selectAppsToDiscourage(result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED",
                    message: "App picker requires iOS 16 or later.",
                    details: nil
                )
            )
            return
        }

        let box = FlutterResultBox(flutterResult: result) { [weak self] in
            self?.activeFamilyPickerPresenter = nil
        }
        Task {
            if await Self.isAuthorizationApproved() == false {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                } catch {
                    await MainActor.run {
                        box.send(
                            FlutterError(
                                code: "AUTH_ERROR",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    }
                    return
                }
            }

            let approved = await Self.waitForAuthorizationApproved()
            guard approved else {
                let statusNote = await Self.authorizationStatusDescription()
                await MainActor.run {
                    box.send(
                        FlutterError(
                            code: "AUTH_DENIED",
                            message:
                                "Screen Time access was not granted (status: \(statusNote)). If you chose Don’t Allow, open Settings → Screen Time and allow access for this app. The app also needs the Family Controls capability on your Apple Developer profile.",
                            details: nil
                        )
                    )
                }
                return
            }

            // Let the system permission UI tear down so key window / view hierarchy is valid.
            try? await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run {
                guard let root = Self.topViewController() else {
                    box.send(
                        FlutterError(
                            code: "NO_VIEW_CONTROLLER",
                            message: "Could not find a view controller to present the app picker. Try again in a moment.",
                            details: nil
                        )
                    )
                    return
                }
                let initial = FamilyPickerPresenter.loadInitialSelection()
                let presenter = FamilyPickerPresenter(resultBox: box)
                self.activeFamilyPickerPresenter = presenter
                presenter.presentPicker(initial: initial, from: root)
            }
        }
    }

    private func encourageAll(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            FamilyPickerPresenter.clearShieldAndPersistence()
        } else {
            ManagedSettingsStore().clearAllSettings()
            UserDefaults.standard.removeObject(forKey: kFamilySelectionDefaultsKey)
        }
        result(nil)
    }

    /// Refreshes usage via an embedded **Device Activity Report** extension (writes JSON to the app group), then returns seconds per app key for Dart.
    private func getScreenTimeData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            result([String: Any]())
            return
        }
        Task { @MainActor in
            let map = await Self.refreshScreenTimeReportAndRead(call: call)
            result(map)
        }
    }

    @available(iOS 16.0, *)
    @MainActor
    private static func refreshScreenTimeReportAndRead(call: FlutterMethodCall) async -> [String: Any] {
        let args = call.arguments as? [String: Any]
        let endMs = (args?["endDate"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000)
        let startMs = (args?["startDate"] as? NSNumber)?.doubleValue ?? (endMs - 7 * 24 * 3600 * 1000)
        let end = Date(timeIntervalSince1970: endMs / 1000)
        let start = Date(timeIntervalSince1970: startMs / 1000)
        let lo = min(start, end)
        let hi = max(start, end)
        let interval = DateInterval(start: lo, end: hi)

        let filter = DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .all
        )

        guard let root = topViewController(), let container = root.view else {
            return readUsageMapFromAppGroup()
        }

        let host = UIHostingController(rootView: ScreenTimeReportTriggerView(filter: filter))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        root.addChild(host)
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.widthAnchor.constraint(equalToConstant: 2),
            host.view.heightAnchor.constraint(equalToConstant: 2),
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor)
        ])
        host.didMove(toParent: root)

        try? await Task.sleep(nanoseconds: 2_500_000_000)

        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()

        return readUsageMapFromAppGroup()
    }

    private static func readUsageMapFromAppGroup() -> [String: Any] {
        guard let defaults = UserDefaults(suiteName: ScreenTimeReportConstants.appGroupId),
              let data = defaults.data(forKey: ScreenTimeReportConstants.usageSecondsKey),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return obj
    }

    /// `AuthorizationCenter.authorizationStatus` should be read on the main actor; it can lag briefly after the system sheet closes.
    private static func isAuthorizationApproved() async -> Bool {
        await MainActor.run {
            AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    /// Polls until approved or timeout (~2s) so we do not treat a slow status update as denial.
    private static func waitForAuthorizationApproved() async -> Bool {
        let maxAttempts = 40
        for _ in 0..<maxAttempts {
            if await isAuthorizationApproved() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return await isAuthorizationApproved()
    }

    private static func authorizationStatusDescription() async -> String {
        await MainActor.run {
            String(describing: AuthorizationCenter.shared.authorizationStatus)
        }
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = {
            if let base { return base }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let foregroundScenes = scenes.filter {
                $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
            }
            let searchScenes = foregroundScenes.isEmpty ? scenes : foregroundScenes
            var roots: [UIViewController] = []
            for scene in searchScenes {
                let keyRoots = scene.windows.filter(\.isKeyWindow).compactMap(\.rootViewController)
                roots.append(contentsOf: keyRoots)
                if keyRoots.isEmpty {
                    let anyRoots = scene.windows.compactMap(\.rootViewController)
                    roots.append(contentsOf: anyRoots)
                }
            }
            return roots.first
        }()

        guard let root = baseVC else { return nil }
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
