import SwiftUI

struct ContentView: View {
    let model: AppModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if model.initialLoadRequired, model.series == nil {
                    InitialLoadRequiredView(
                        message: model.initialLoadError ?? AppStrings.Messages.initialQuotesRequired,
                        isRefreshing: model.isRefreshing,
                        onRetry: {
                            Task { await model.refresh(manual: true) }
                        }
                    )
                } else if model.series == nil {
                    LoadingView()
                } else if let series = model.series {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let inlineMessage = model.inlineMessage {
                                MessageCard(text: inlineMessage, accent: .blue, symbol: "checkmark.circle.fill")
                            }

                            if model.input == nil || model.isEditingCase {
                                LoanEditorView(
                                    existingInput: model.input,
                                    series: series,
                                    onSave: { model.saveCase($0) },
                                    onCancel: { model.cancelEditingCase() }
                                )
                            } else {
                                DashboardView(model: model, series: series)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                    .background(
                        AppBackground()
                            .ignoresSafeArea()
                    )
                    .safeAreaInset(edge: .top) {
                        DataStatusCard(
                            lastUpdateDateText: model.lastUpdateDateText,
                            isRefreshing: model.isRefreshing,
                            onRefresh: { Task { await model.refresh(manual: true) } }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .background(
                AppBackground()
                    .ignoresSafeArea()
            )
            .navigationTitle(AppStrings.Common.appName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.startIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await model.refreshFromForegroundIfNeeded()
            }
        }
    }
}

struct AppBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            CardContainer(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: 14) {
                    ProgressView()
                        .controlSize(.regular)

                    Text(AppStrings.Content.loadingTitle)
                        .font(.title3.bold())

                    Text(AppStrings.Content.loadingSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }
}

struct InitialLoadRequiredView: View {
    let message: String
    let isRefreshing: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(AppStrings.Content.initialLoadTitle)
                .font(.title2.bold())

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)

            Button {
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(AppStrings.Content.retryInitialDownload)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRefreshing)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }
}

struct DataStatusCard: View {
    let lastUpdateDateText: String
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Content.dataStatusTitle(lastUpdateDateText))
                    .font(.subheadline.weight(.semibold))
                Text(AppStrings.Common.updatedWithClose)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct MessageCard: View {
    let text: String
    let accent: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(accent)
                .font(.body.weight(.semibold))
                .padding(.top, 1)
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct InsightChip: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.10), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

enum CardEmphasis {
    case normal
    case subtle
}

struct CardContainer<Content: View>: View {
    let emphasis: CardEmphasis
    @ViewBuilder let content: Content

    init(emphasis: CardEmphasis = .normal, @ViewBuilder content: () -> Content) {
        self.emphasis = emphasis
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(border)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
    }

    @ViewBuilder
    private var background: some View {
        switch emphasis {
        case .normal:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        case .subtle:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    @ViewBuilder
    private var border: some View {
        switch emphasis {
        case .normal, .subtle:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var shadowColor: Color {
        switch emphasis {
        case .normal: return Color.black.opacity(0.04)
        case .subtle: return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch emphasis {
        case .normal: return 16
        case .subtle: return 0
        }
    }

    private var shadowYOffset: CGFloat {
        switch emphasis {
        case .normal: return 8
        case .subtle: return 0
        }
    }
}
