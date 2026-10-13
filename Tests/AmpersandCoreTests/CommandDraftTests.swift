import Foundation
import Testing
@testable import AmpersandCore

@Test func pastedLineProducesChipsAndStrippedSpec() {
    var d = CommandDraft()
    d.commandText = "cd ~/dev/web && PORT=3001 npm run dev"
    #expect(d.suggestions.map(\.label) == ["Folder ~/dev/web", "Env PORT=3001", "Port 3001", "Name dev"])
    let spec = d.makeSpec()
    #expect(spec.command == "npm run dev")
    #expect(spec.cwd == "~/dev/web")
    #expect(spec.env == "PORT=3001")
    #expect(spec.port == 3001)
    #expect(spec.name == "dev")
}

@Test func dismissingAPrefixChipKeepsTheLineAsTyped() {
    var d = CommandDraft()
    d.commandText = "cd ~/dev/web && npm run dev"
    d.dismissedChips = [.cwd]
    let spec = d.makeSpec()
    #expect(spec.command == "cd ~/dev/web && npm run dev")
    #expect(spec.cwd == nil)
    #expect(!d.suggestions.contains { $0.chip == .cwd })
}

@Test func explicitFieldsWinAndHideChips() {
    var d = CommandDraft()
    d.commandText = "cd ~/a && vite --port 5173"
    d.name = "web"
    d.portText = "4000"
    d.cwd = "~/b"
    #expect(d.suggestions.map(\.chip) == [])
    let spec = d.makeSpec()
    #expect(spec.name == "web" && spec.port == 4000 && spec.cwd == "~/b")
    #expect(spec.command == "cd ~/a && vite --port 5173")
}

@Test func envChipPrependsToExistingEnvText() {
    var d = CommandDraft()
    d.commandText = "A=1 run"
    d.envText = "# mine\nB=2"
    #expect(d.makeSpec().env == "A=1\n# mine\nB=2")
}

@Test func kubectlSuggestsTCPHealth() {
    var d = CommandDraft()
    d.commandText = "kubectl port-forward svc/api 8080:80"
    #expect(d.suggestions.map(\.label) == ["Port 8080", "Name api", "TCP Health Check"])
    #expect(d.makeSpec().health == .tcp)
    d.dismissedChips = [.health]
    #expect(d.makeSpec().health == nil)
}

@Test func existingSpecRoundTripsWithoutChips() {
    let spec = CommandSpec(name: "web", command: "PORT=1 npm run dev", cwd: "~/w", env: "A=1", envFile: "~/.env",
                           group: "g", autoStart: true, port: 3000, health: .http(url: "http://localhost:3000"), restart: false)
    let d = CommandDraft(spec: spec)
    #expect(d.suggestions.isEmpty)
    #expect(d.makeSpec() == spec)
    var changed = d
    changed.commandText = "PORT=2 npm run dev"
    #expect(changed.suggestions.map(\.chip) == [.env])
}

@Test func validationMessages() {
    var d = CommandDraft()
    #expect(d.validationMessage == "Enter a command.")
    d.commandText = "run"
    #expect(d.isValid)
    d.portText = "70000"
    #expect(d.validationMessage == "Port must be a number from 1 to 65535.")
    d.portText = ""
    d.health = .port
    #expect(d.validationMessage == "A port health check needs a port.")
    d.health = .url
    d.healthURL = "localhost:3000"
    #expect(d.validationMessage == "Enter a URL that starts with http:// or https://.")
    d.health = .none
    d.envText = "OK=1\nbad line"
    #expect(d.validationMessage == "Environment line 2: Expected KEY=value")
}

@Test func newDraftUsesRestartDefault() {
    #expect(CommandDraft(restartDefault: false).restart == false)
    #expect(CommandDraft().restart == true)
}
