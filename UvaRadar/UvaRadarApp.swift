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
        let casePersistence = JSONCasePersistence()
        _model = State(initialValue: AppModel(seriesRepository: seriesRepository, casePersistence: casePersistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
