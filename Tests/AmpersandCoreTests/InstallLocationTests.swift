import Testing
@testable import AmpersandCore

@Test func applicationsFolders() {
    #expect(InstallLocation(bundlePath: "/Applications/Ampersand.app", home: "/Users/me") == .applications)
    #expect(InstallLocation(bundlePath: "/Applications/Tools/Ampersand.app", home: "/Users/me") == .applications)
    #expect(InstallLocation(bundlePath: "/Users/me/Applications/Ampersand.app", home: "/Users/me") == .applications)
}

@Test func translocatedCopy() {
    let path = "/private/var/folders/ab/xyz/T/AppTranslocation/0F3C-11AA/d/Ampersand.app"
    #expect(InstallLocation(bundlePath: path, home: "/Users/me") == .translocated)
}

@Test func elsewhere() {
    #expect(InstallLocation(bundlePath: "/Volumes/Ampersand/Ampersand.app", home: "/Users/me") == .elsewhere)
    #expect(InstallLocation(bundlePath: "/Users/me/Downloads/Ampersand.app", home: "/Users/me") == .elsewhere)
    #expect(InstallLocation(bundlePath: "/Users/me/dev/ampersand/build/Ampersand.app", home: "/Users/me") == .elsewhere)
    // A folder whose name only starts with "Applications" is not the Applications folder.
    #expect(InstallLocation(bundlePath: "/ApplicationsOld/Ampersand.app", home: "/Users/me") == .elsewhere)
}

@Test func normalisesThePath() {
    #expect(InstallLocation(bundlePath: "/Users/me/Downloads/../../../Applications/Ampersand.app", home: "/Users/me")
            == .applications)
}
