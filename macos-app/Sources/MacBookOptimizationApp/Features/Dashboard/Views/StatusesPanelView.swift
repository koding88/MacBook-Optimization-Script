import SwiftUI

struct StatusesPanelView: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel

    let localizer: AppLocalizer
    let actions: [OptimizationAction]

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.panelAllStatuses))
                            .font(.title3.weight(.semibold))

                        Text(localizer.text(.statusCatalog))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(localizer.text(.statusReset)) {
                        model.resetStoredStatuses()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 6)
            }

            if actions.allSatisfy({ $0.lastRunDescription == nil && $0.status == .ready }) {
                Section {
                    Text(localizer.text(.statusEmpty))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(ActionCategory.allCases) { category in
                    let categoryActions = actions
                        .filter { $0.category == category }
                        .sorted { localizer.string($0.titleKey) < localizer.string($1.titleKey) }

                    if !categoryActions.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryActions) { action in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localizer.string(action.titleKey))
                                            .font(.headline)

                                        Text(localizer.string(action.descriptionKey))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let lastRun = action.lastRunDescription {
                                            Text("\(localizer.text(.lastRun)): \(lastRun)")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    Spacer(minLength: 12)

                                    StatusIndicatorView(status: action.status, localizer: localizer)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(localizer.text(.panelAllStatuses))
    }
}
