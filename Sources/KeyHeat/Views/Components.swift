import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Palette.hairline).frame(height: 1)
    }
}

/// A single figure with its label underneath. No box.
struct Stat: View {
    let value: String
    let label: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.system(size: 12)).foregroundStyle(Palette.muted)
            Text(detail ?? " ").font(.system(size: 12)).foregroundStyle(Palette.inkSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text-only segmented control: the selected option is black, the rest gray.
struct TextSegments<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 18) {
            ForEach(options, id: \.0) { value, title in
                Button(title) { selection = value }
                    .buttonStyle(.plain)
                    .font(.system(size: size, weight: selection == value ? .semibold : .regular))
                    .foregroundStyle(selection == value ? Palette.ink : Palette.muted)
            }
        }
    }
}

/// Text-only button in the chrome.
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Palette.inkSecondary)
    }
}

/// Small floating label used as a hover tooltip inside charts.
struct ChartTip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 5).fill(Palette.background).shadow(color: .black.opacity(0.12), radius: 4, y: 1))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

struct EmptyNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
}

enum Fmt {
    static func percent(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }

    static func hourLabel(_ h: Int) -> String {
        var comps = DateComponents()
        comps.hour = h
        let d = Calendar.current.date(from: comps) ?? Date()
        return d.formatted(.dateTime.hour())
    }

    static func compact(_ n: Int) -> String {
        n.formatted(.number.notation(.compactName))
    }
}
