import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showCustomize = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if model.hasData {
                    content
                } else {
                    VStack(spacing: 0) {
                        TodayHeader()
                            .padding(.horizontal, 16)
                        Spacer()
                        EmptyDataHint(text: model.isConnected
                            ? model.loc("Noch keine Daten – starte oben rechts eine Synchronisierung.", "No data yet – tap sync in the top right corner.")
                            : model.loc("Keine Daten vorhanden. Verbinde Google Health oder starte den Demo-Modus unter „Mehr“.", "No data. Connect Google Health or start demo mode under More."))
                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCustomize) {
                DashboardCustomizeSheet()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 18) {
                    TodayHeader()
                    PulseWordmark()
                    ScoreRingsRow()
                }

                if model.syncing {
                    syncBanner
                }
                if let error = model.lastError, !model.syncing {
                    errorBanner(error)
                }

                InsightCard()

                HStack(spacing: 12) {
                    HealthMonitorTile()
                    PulseAgeTile()
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 14) {
                    MyDayHeader { showCustomize = true }
                    DayReviewBanner()
                    ForEach(model.visibleModules) { module in
                        moduleView(module)
                    }
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable {
            if model.isConnected {
                await model.syncNow()
            }
        }
    }

    // MARK: - Module

    @ViewBuilder
    private func moduleView(_ module: DashboardModule) -> some View {
        switch module {
        case .workouts: WorkoutsCard()
        case .steps: StepsCard()
        case .journal: JournalCard()
        }
    }

    // MARK: - Banner

    private var syncBanner: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProgressView()
                    Text(model.syncMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                ProgressView(value: model.syncFraction)
                    .tint(Theme.teal)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.yellow)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    model.lastError = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    static func deltaText(_ delta: Double) -> String {
        let rounded = Int(abs(delta).rounded())
        if Fmt.language == .de {
            if rounded == 0 { return "Genau in deinem Alter" }
            let unit = rounded == 1 ? "Jahr" : "Jahre"
            return delta < 0 ? "\(rounded) \(unit) jünger" : "\(rounded) \(unit) älter"
        }
        if rounded == 0 { return "Exactly your age" }
        let unit = rounded == 1 ? "year" : "years"
        return delta < 0 ? "\(rounded) \(unit) younger" : "\(rounded) \(unit) older"
    }

    static func deltaColor(_ delta: Double) -> Color {
        if delta <= -1 { return Theme.green }
        if delta >= 1 { return Theme.orange }
        return Theme.textSecondary
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let lastSync = model.lastSyncAt {
                Text(model.loc("Letzter Sync: \(Fmt.relative(lastSync))", "Last sync: \(Fmt.relative(lastSync))"))
            } else if model.demoMode {
                Text(model.loc("Demo-Modus – generierte Beispieldaten", "Demo mode – generated sample data"))
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
        .padding(.top, 4)
    }
}

// MARK: - Kopfzeile

/// Eigene Kopfzeile statt Navigation-Bar: links Demo-Badge, mittig der
/// Tageswechsler, rechts der Sync-Knopf.
struct TodayHeader: View {
    @Environment(AppModel.self) private var model

    private var today: String { DayKey.today() }

    private var earliest: String {
        model.availableKeys.first ?? today
    }

    private var canGoBack: Bool { model.selectedDayKey > earliest }
    private var canGoForward: Bool { model.selectedDayKey < today }

    private var dayLabel: String {
        let key = model.selectedDayKey
        if key == today || key == DayKey.addDays(today, -1) {
            return Fmt.dayTitle(key)
        }
        return Fmt.dayShort(key)
    }

    var body: some View {
        HStack {
            if model.demoMode {
                PillBadge(text: "Demo", color: Theme.yellow)
            }
            Spacer()
            if model.isConnected {
                Button {
                    Task { await model.syncNow() }
                } label: {
                    Group {
                        if model.syncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                }
                .disabled(model.syncing)
            }
        }
        .frame(height: 44)
        .overlay {
            dayNavigator
        }
        .padding(.top, 4)
    }

    private var dayNavigator: some View {
        HStack(spacing: 2) {
            arrow("chevron.left", enabled: canGoBack) { step(-1) }
            Text(dayLabel.uppercased())
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .kerning(1.4)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Theme.cardElevated))
            arrow("chevron.right", enabled: canGoForward) { step(1) }
        }
        .padding(4)
        .background(Capsule().fill(Theme.card))
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(enabled ? Theme.textSecondary : Theme.textSecondary.opacity(0.3))
                .frame(width: 32, height: 36)
        }
        .disabled(!enabled)
    }

    private func step(_ days: Int) {
        let next = DayKey.addDays(model.selectedDayKey, days)
        guard next >= earliest, next <= today else { return }
        model.selectedDayKey = next
    }
}

struct PulseWordmark: View {
    var body: some View {
        Text("PULSE")
            .font(.system(size: 26, weight: .light, design: .rounded))
            .kerning(5)
            .foregroundStyle(Theme.textSecondary)
            .accessibilityHidden(true)
    }
}

// MARK: - Score-Ringe

/// Voller Ring mit neutraler Spur, großer Zahl in der Mitte und Label mit
/// Chevron darunter. `marker` (0–1) zeichnet den weißen Ziel-Strich.
struct ScoreRing: View {
    var progress: Double?  // 0–1, nil = keine Daten
    var color: Color
    var value: String
    var suffix: String? = nil
    var label: String
    var marker: Double? = nil

    private let lineWidth: CGFloat = 9

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
                if let progress {
                    Circle()
                        .trim(from: 0, to: CGFloat(Stats.clamp(progress, 0.004, 1)))
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                if let marker {
                    GeometryReader { geo in
                        let radius = min(geo.size.width, geo.size.height) / 2
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 3, height: lineWidth + 6)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - radius)
                            .rotationEffect(.degrees(Stats.clamp(marker, 0, 1) * 360))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let suffix, progress != nil {
                        Text(suffix)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(progress == nil ? Theme.textSecondary : Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, lineWidth + 4)
            }
            .padding(lineWidth / 2)
            .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 4) {
                Text(label.uppercased())
                    .kerning(1.6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
    }
}

struct ScoreRingsRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)
        let sleep = model.sleep(for: key).flatMap { $0.hasData ? $0 : nil }
        let strain = model.strain(for: key)
        let target = recovery.map { StrainEngine.targetStrain(forRecovery: $0.score) }

        HStack(alignment: .top, spacing: 14) {
            NavigationLink {
                SleepDetailView()
            } label: {
                ScoreRing(
                    progress: sleep.map { $0.performance / 100 },
                    color: Theme.sleepPurple,
                    value: sleep.map { "\(Int($0.performance.rounded()))" } ?? "–",
                    suffix: "%",
                    label: model.loc("Schlaf", "Sleep")
                )
            }
            NavigationLink {
                RecoveryDetailView()
            } label: {
                ScoreRing(
                    progress: recovery.map { Double($0.score) / 100 },
                    color: recovery.map { Theme.recoveryColor(zone: $0.zone) } ?? Theme.textSecondary,
                    value: recovery.map { "\($0.score)" } ?? "–",
                    suffix: "%",
                    label: "Recovery"
                )
            }
            NavigationLink {
                StrainDetailView()
            } label: {
                ScoreRing(
                    progress: strain.map { $0.strain / 21 },
                    color: Theme.strainBlue,
                    value: strain.map { String(format: "%.1f", $0.strain) } ?? "–",
                    label: "Strain",
                    marker: strain == nil ? nil : target.map { $0 / 21 }
                )
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}

// MARK: - Hinweis-Karte

/// Ein Coaching-Hinweis aus bereits berechneten Werten (keine eigene Logik).
private struct Insight: Identifiable {
    let id: String
    let title: String
    let message: String
    let symbol: String
    let tint: Color
}

/// Stapel von Hinweisen: zeigt einen, das Badge zählt alle, Tippen blättert.
struct InsightCard: View {
    @Environment(AppModel.self) private var model
    @State private var index = 0

    private var insights: [Insight] {
        let key = model.selectedDayKey
        let isToday = key == DayKey.today()
        let bedtime = isToday ? model.bedtimeTonight?.recommendedBedtimeMinutes : nil
        let bedtimeText = bedtime.map {
            model.loc(" Ziel: bis \(Fmt.clockFromMinutes($0)) ins Bett.", " Aim to be in bed by \(Fmt.clockFromMinutes($0)).")
        } ?? ""
        var list: [Insight] = []

        if let alert = model.healthAlert {
            list.append(Insight(
                id: "health",
                title: model.loc("Gesundheits-Hinweis", "Health notice"),
                message: alert.message,
                symbol: "waveform.path.ecg",
                tint: Theme.orange
            ))
        }

        let recovery = model.recovery(for: key)
        if isToday, let strain = model.strain(for: key), let recovery {
            let target = StrainEngine.targetStrain(forRecovery: recovery.score)
            if strain.strain >= target {
                list.append(Insight(
                    id: "strain",
                    title: model.loc("Ziel erreicht", "Past your target"),
                    message: model.loc("Du hast dein heutiges Belastungsziel überschritten. Priorisiere heute Nacht deinen Schlaf, um dich zu erholen.", "You are past today\u{2019}s target. Prioritise sleep tonight to recover.") + bedtimeText,
                    symbol: "checkmark",
                    tint: Theme.strainBlue
                ))
            } else {
                list.append(Insight(
                    id: "strain",
                    title: model.loc("Ziel heute: \(String(format: "%.1f", target))", "Today\u{2019}s target: \(String(format: "%.1f", target))"),
                    message: model.loc("Noch \(String(format: "%.1f", target - strain.strain)) Strain bis zum Ziel – bisher \(String(format: "%.1f", strain.strain)).", "\(String(format: "%.1f", target - strain.strain)) strain to go – \(String(format: "%.1f", strain.strain)) so far."),
                    symbol: "flame",
                    tint: Theme.strainBlue
                ))
            }
        }

        if let sleep = model.sleep(for: key), sleep.hasData, sleep.debtAfterMinutes > 5 {
            list.append(Insight(
                id: "debt",
                title: model.loc("Schlafschuld", "Sleep debt"),
                message: model.loc("Du hast \(Fmt.hm(sleep.debtAfterMinutes)) h Schlafschuld angesammelt.", "You are carrying \(Fmt.hm(sleep.debtAfterMinutes)) h of sleep debt.") + bedtimeText,
                symbol: "bed.double",
                tint: Theme.sleepPurple
            ))
        }

        if let recovery, recovery.calibrating {
            list.append(Insight(
                id: "calibrating",
                title: model.loc("Kalibrierung", "Calibrating"),
                message: model.loc("Baseline kalibriert noch (< 5 Nächte).", "Baseline still calibrating (< 5 nights)."),
                symbol: "hourglass",
                tint: Theme.yellow
            ))
        }
        return list
    }

    var body: some View {
        let list = insights
        if !list.isEmpty {
            let current = list[index % list.count]
            ZStack(alignment: .bottom) {
                if list.count > 1 {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.card.opacity(0.6))
                        .frame(height: 40)
                        .padding(.horizontal, 22)
                        .offset(y: 10)
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(current.title)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(current.message)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)

                    VStack(spacing: 8) {
                        Image(systemName: current.symbol)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(current.tint)
                        if list.count > 1 {
                            Text("\(list.count)")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(width: 36)
                    .background(Capsule().fill(Theme.cardElevated))
                }
                .padding(20)
                .frame(minHeight: 120, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 1)
                        )
                )
            }
            .padding(.bottom, list.count > 1 ? 10 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                guard list.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    index = (index + 1) % list.count
                }
            }
            .onChange(of: model.selectedDayKey) {
                index = 0
            }
        }
    }
}

// MARK: - Monitor-Kacheln

private struct MonitorTile<Badge: View>: View {
    let title: String
    let status: String
    let statusColor: Color
    let detail: String
    @ViewBuilder var badge: Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                badge
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.uppercased())
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .kerning(0.8)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

private struct TileBadge: View {
    var symbol: String? = nil
    var text: String? = nil
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.opacity(0.18))
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.headline.weight(.bold))
                } else if let text {
                    Text(text)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                }
            }
            .foregroundStyle(color)
    }
}

struct HealthMonitorTile: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let statuses = model.healthStatuses.filter { $0.state != .noData }
        let inRange = statuses.filter { $0.state == .inRange }.count
        let outside = statuses.filter { $0.state == .above || $0.state == .below }.count
        let detail = model.loc("\(inRange)/\(statuses.count) im Bereich", "\(inRange)/\(statuses.count) within range")

        NavigationLink {
            HealthMonitorContent()
                .navigationTitle(model.loc("Gesundheit", "Health"))
        } label: {
            Group {
                if statuses.isEmpty {
                    MonitorTile(title: model.loc("Health-Monitor", "Health monitor"),
                                status: model.loc("Keine Daten", "No data"),
                                statusColor: Theme.textSecondary,
                                detail: model.loc("Keine Nachtwerte", "No overnight data")) {
                        TileBadge(symbol: "minus", color: Theme.textSecondary)
                    }
                } else if outside > 0 {
                    MonitorTile(title: model.loc("Health-Monitor", "Health monitor"),
                                status: model.loc("\(outside) außerhalb", "\(outside) out of range"),
                                statusColor: Theme.orange,
                                detail: detail) {
                        TileBadge(symbol: "exclamationmark", color: Theme.orange)
                    }
                } else if inRange == 0 {
                    MonitorTile(title: model.loc("Health-Monitor", "Health monitor"),
                                status: model.loc("Kalibriert", "Calibrating"),
                                statusColor: Theme.textSecondary,
                                detail: detail) {
                        TileBadge(symbol: "hourglass", color: Theme.textSecondary)
                    }
                } else {
                    MonitorTile(title: model.loc("Health-Monitor", "Health monitor"),
                                status: model.loc("Im Bereich", "Within range"),
                                statusColor: Theme.green,
                                detail: detail) {
                        TileBadge(symbol: "checkmark", color: Theme.green)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PulseAgeTile: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let title = model.loc("Pulse Alter", "Pulse Age")
        NavigationLink {
            AgeDetailView()
        } label: {
            Group {
                if let result = model.ageResult(for: model.selectedDayKey) {
                    if let pulseAge = result.pulseAge, let delta = result.deltaYears {
                        MonitorTile(title: title,
                                    status: DashboardView.deltaText(delta),
                                    statusColor: DashboardView.deltaColor(delta),
                                    detail: model.loc("Chronologisch: \(result.chronoAge)", "Chronological: \(result.chronoAge)")) {
                            TileBadge(text: "\(Int(pulseAge.rounded()))", color: Theme.teal)
                        }
                    } else {
                        MonitorTile(title: title,
                                    status: model.loc("Kalibriert", "Calibrating"),
                                    statusColor: Theme.yellow,
                                    detail: model.loc("Tag \(result.calibrationHave)/\(result.calibrationNeed)", "Day \(result.calibrationHave)/\(result.calibrationNeed)")) {
                            TileBadge(symbol: "hourglass", color: Theme.yellow)
                        }
                    }
                } else {
                    MonitorTile(title: title,
                                status: model.loc("Keine Daten", "No data"),
                                statusColor: Theme.textSecondary,
                                detail: model.loc("Noch nicht verfügbar", "Not available yet")) {
                        TileBadge(symbol: "minus", color: Theme.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mein Tag

struct MyDayHeader: View {
    @Environment(AppModel.self) private var model
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(model.loc("Mein Tag", "My Day"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.textPrimary))
            }
            .accessibilityLabel(model.loc("Mein Tag anpassen", "Customize My Day"))
        }
        .padding(.top, 8)
    }
}

/// Banner zur großen Tages-Übersicht (drei Ringe im Detail).
struct DayReviewBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink {
            OverviewDetailView()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "moon")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
                Text(model.loc("Dein Tag im Rückblick", "Your day in review"))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Theme.strainBlue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x2E2A5C), Color(hex: 0x24364A)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
        }
        .buttonStyle(.plain)
    }
}
