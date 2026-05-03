import Foundation
import Combine

@MainActor
final class ActivityCoordinator: ObservableObject {
    static let shared = ActivityCoordinator()
    
    @Published private(set) var currentEvent: SystemEvent = .appIdle
    @Published private(set) var activeProvider: AIProvider = .unknown
    
    private var cancellables = Set<AnyCancellable>()
    private var transientTimer: Timer?
    private let minimumStateDuration: TimeInterval = 2.0
    
    private var persistentStates: [AIProvider: SystemEvent] = [:]
    private var lastTransient: (AIProvider, SystemEvent)?
    
    private init() {}
    
    func start(sources: [SystemEventSource]) {
        for source in sources {
            source.events
                .receive(on: DispatchQueue.main)
                .sink { [weak self] provider, event in
                    self?.handleEvent(provider, event)
                }
                .store(in: &cancellables)
        }
    }
    
    func startForPreview() {
        start(sources: [ManualDebugEventSource.shared])
    }
    
    private func handleEvent(_ provider: AIProvider, _ event: SystemEvent) {
        if isPersistent(event) {
            persistentStates[provider] = event
        } else if event == .quotaRecovered {
            persistentStates[provider] = .appIdle
        } else if event != .appIdle {
            lastTransient = (provider, event)
            startTransientTimer()
        }

        updateCurrentState()
    }
    
    private func startTransientTimer() {
        transientTimer?.invalidate()
        transientTimer = Timer.scheduledTimer(withTimeInterval: minimumStateDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lastTransient = nil
                self?.updateCurrentState()
            }
        }
    }
    
    private func updateCurrentState() {
        var highest: (AIProvider, SystemEvent) = (.unknown, .appIdle)
        
        // Check persistent states
        for (p, s) in persistentStates {
            if priority(for: s) > priority(for: highest.1) {
                highest = (p, s)
            }
        }
        
        // Check transient state
        if let transient = lastTransient {
            if priority(for: transient.1) >= priority(for: highest.1) {
                highest = transient
            }
        }
        
        currentEvent = highest.1
        activeProvider = highest.0
    }
    
    private func isPersistent(_ event: SystemEvent) -> Bool {
        switch event {
        case .quotaLow, .requestFailed, .quotaResetting: return true
        default: return false
        }
    }
    
    private func priority(for event: SystemEvent) -> Int {
        switch event {
        case .requestFailed:   return 100
        case .quotaLow:        return 90
        case .quotaResetting:  return 80
        case .aiStreaming:     return 70
        case .aiThinking:      return 60
        case .requestSucceeded: return 50
        case .quotaRecovered:  return 40
        case .userStartedRequest: return 30
        case .appIdle:         return 0
        }
    }
}
