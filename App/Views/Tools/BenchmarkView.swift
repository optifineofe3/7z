//
//  BenchmarkView.swift
//  7Zip Hardware Performance Benchmark View
//

import SwiftUI

public struct BenchmarkView: View {
    @State private var isRunning: Bool = false
    @State private var iterations: Int = 1
    @State private var logLines: [String] = []
    @State private var compressionMIPS: Int = 0
    @State private var decompressionMIPS: Int = 0
    @State private var totalMIPS: Int = 0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(spacing: 12) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.accent)
                    Text(NSLocalizedString("benchmark_title", comment: ""))
                        .font(.title2)
                        .bold()
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Measure CPU compression & decompression throughput in MIPS using original 7-Zip benchmark engine.")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .appCardStyle()

                // Results Card if benchmark has run
                if totalMIPS > 0 || isRunning {
                    VStack(spacing: 16) {
                        if isRunning {
                            ProgressView()
                                .tint(AppTheme.accent)
                            Text("Benchmarking CPU cores...")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        } else {
                            VStack(spacing: 4) {
                                Text("\(totalMIPS)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.accent)
                                Text("TOTAL MIPS")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            Divider().background(AppTheme.divider)

                            HStack(spacing: 24) {
                                VStack(spacing: 4) {
                                    Text("\(compressionMIPS)")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Compressing")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                VStack(spacing: 4) {
                                    Text("\(decompressionMIPS)")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Decompressing")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .appCardStyle()
                }

                // Controls Card
                VStack(spacing: 16) {
                    Stepper("Iterations: \(iterations)", value: $iterations, in: 1...10)
                        .foregroundColor(AppTheme.textPrimary)
                        .disabled(isRunning)

                    Button(action: isRunning ? cancelBenchmark : startBenchmark) {
                        Text(isRunning ? "Stop Benchmark" : NSLocalizedString("start_benchmark", comment: ""))
                            .font(.headline)
                            .bold()
                            .foregroundColor(isRunning ? AppTheme.accent : AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isRunning ? AppTheme.cardBackgroundSecondary : AppTheme.accent)
                            .cornerRadius(12)
                    }
                }
                .appCardStyle()

                // Console output
                if !logLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Benchmark Log")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(logLines.suffix(30).enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCardStyle()
                }
            }
            .padding(16)
        }
        .appBackground()
        .navigationTitle(NSLocalizedString("benchmark_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startBenchmark() {
        isRunning = true
        logLines.removeAll()
        compressionMIPS = 0
        decompressionMIPS = 0
        totalMIPS = 0
        AppTheme.triggerImpact(style: .medium)

        SevenZipBridge.shared.execute(
            arguments: ["7zz", "b", "\(iterations)"],
            onLog: { line in
                DispatchQueue.main.async {
                    self.logLines.append(line)
                    self.parseBenchmarkLine(line)
                }
            },
            completion: { code in
                DispatchQueue.main.async {
                    self.isRunning = false
                    AppTheme.triggerHaptic(type: code == SZ_OK ? .success : .error)
                }
            }
        )
    }

    private func cancelBenchmark() {
        SevenZipBridge.shared.cancel()
        isRunning = false
    }

    private func parseBenchmarkLine(_ line: String) {
        // Look for lines like "Tot: ... 12345" or summary lines
        let parts = line.split(separator: " ").map(String.init)
        if line.contains("Compressing") {
            if let last = parts.last, let val = Int(last) {
                compressionMIPS = val
            }
        } else if line.contains("Decompressing") {
            if let last = parts.last, let val = Int(last) {
                decompressionMIPS = val
            }
        } else if line.contains("Tot:") {
            if let last = parts.last, let val = Int(last) {
                totalMIPS = val
            }
        }
    }
}
