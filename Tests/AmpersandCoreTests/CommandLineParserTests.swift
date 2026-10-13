import Testing
@testable import AmpersandCore

@Test func cdPrefixBecomesCwd() {
    let s = CommandLineParser.parse("cd ~/dev/web && npm run dev")
    #expect(s.cwd == "~/dev/web")
    #expect(s.command == "npm run dev")
    #expect(s.name == "dev")
}

@Test func quotedCdPath() {
    let s = CommandLineParser.parse(#"cd "~/My Projects/web" && npm start"#)
    #expect(s.cwd == "~/My Projects/web")
    #expect(s.command == "npm start")
    #expect(s.name == "start")
}

@Test func leadingEnvAssignments() {
    let s = CommandLineParser.parse(#"PORT=3001 NODE_ENV="dev mode" npm start"#)
    #expect(s.envLines == ["PORT=3001", #"NODE_ENV="dev mode""#])
    #expect(s.port == 3001)
    #expect(s.command == "npm start")
}

@Test func kubectlPortForward() {
    let s = CommandLineParser.parse("kubectl port-forward svc/api 8080:80 -n storefront")
    #expect(s.name == "api")
    #expect(s.port == 8080)
    #expect(s.health == .tcp)
    #expect(s.command == "kubectl port-forward svc/api 8080:80 -n storefront")
}

@Test func kubectlSinglePortAndAddressFlag() {
    let s = CommandLineParser.parse("kubectl -n x port-forward --address 0.0.0.0 pod/db-0 5432")
    #expect(s.name == "db-0")
    #expect(s.port == 5432)
}

@Test func portFlags() {
    #expect(CommandLineParser.parse("vite --port 5173").port == 5173)
    #expect(CommandLineParser.parse("vite --port=5174").port == 5174)
    #expect(CommandLineParser.parse("next dev -p 3000").port == 3000)
    #expect(CommandLineParser.parse("tail -p 3000 file").port == nil)
}

@Test func plainProgramName() {
    let s = CommandLineParser.parse("  /usr/bin/caffeinate -dimsu  ")
    #expect(s.name == "caffeinate")
    #expect(s.command == "/usr/bin/caffeinate -dimsu")
    #expect(s.cwd == nil && s.envLines.isEmpty && s.port == nil && s.health == nil)
}

@Test func emptyInput() {
    #expect(CommandLineParser.parse("   ") == CommandSuggestions(command: "", cwd: nil, envLines: [], port: nil, name: nil, health: nil))
}
