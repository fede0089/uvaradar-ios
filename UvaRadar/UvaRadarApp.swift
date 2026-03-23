//
//  UvaRadarApp.swift
//  UvaRadar
//
//  Created by Federico Mete on 15/03/2026.
//

import SwiftUI

@main
struct UvaRadarApp: App {
    @State private var model: AppModel

    init() {
        let seriesRepository = LiveSeriesRepository(config: .default)
        let casePersistence = iCloudKVCasePersistence()
        _model = State(
            initialValue: AppModel(
                seriesRepository: seriesRepository,
                casePersistence: casePersistence,
                analytics: AppAnalytics.shared
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
