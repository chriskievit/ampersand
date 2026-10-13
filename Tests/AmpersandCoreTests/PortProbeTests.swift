import Darwin
import Testing
@testable import AmpersandCore

@Test func parsesLsofFieldOutput() {
    #expect(PortProbe.parse("p4412\ncnode\nf23\n") == PortOwner(pid: 4412, name: "node"))
    #expect(PortProbe.parse("") == nil)
}

@Test func findsOwnListener() async throws {
    let server = try await TestServer(response: nil)
    let owner = await PortProbe.owner(of: server.port)
    #expect(owner?.pid == getpid())
    server.stop()
}

@Test func freePortHasNoOwner() async {
    #expect(await PortProbe.owner(of: 1) == nil)
}
