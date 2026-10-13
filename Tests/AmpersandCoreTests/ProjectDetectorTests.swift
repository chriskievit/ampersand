import Foundation
import Testing
@testable import AmpersandCore

private func fixture(_ name: String) -> URL {
    Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent(name)
}

@Test func detectsViteProject() throws {
    let project = try #require(ProjectDetector.detect(folder: fixture("vite-app")))
    #expect(project.name == "web")
    #expect(project.packageManager == "pnpm")
    #expect(project.scripts.map(\.name) == ["dev", "storybook", "build", "preview", "test"])
    let byName = Dictionary(uniqueKeysWithValues: project.scripts.map { ($0.name, $0) })
    #expect(byName["dev"]?.command == "pnpm run dev")
    #expect(byName["dev"]?.port == 5174)
    #expect(byName["storybook"]?.port == 6007)
    #expect(byName["preview"]?.port == 4173)
    #expect(byName["build"]?.port == nil)
    #expect(byName["test"]?.port == nil)
}

@Test func detectsNextProjectWithFolderName() throws {
    let project = try #require(ProjectDetector.detect(folder: fixture("next-app")))
    #expect(project.name == "next-app")
    #expect(project.packageManager == "yarn")
    #expect(project.scripts.map(\.name) == ["dev", "start", "lint"])
    #expect(project.scripts.map(\.port) == [3000, 4000, nil])
}

@Test func noPackageJsonMeansNoProject() {
    #expect(ProjectDetector.detect(folder: fixture("no-package")) == nil)
}

@Test func makeSpecsForSelection() throws {
    let project = try #require(ProjectDetector.detect(folder: fixture("vite-app")))
    let specs = ProjectDetector.makeSpecs(for: project, selecting: ["dev", "storybook"], group: "web")
    #expect(specs.map(\.name) == ["dev", "storybook"])
    #expect(specs[0].command == "pnpm run dev")
    #expect(specs[0].cwd == (project.folder.path as NSString).abbreviatingWithTildeInPath)
    #expect(specs[0].port == 5174)
    #expect(specs.allSatisfy { $0.group == "web" && $0.health == nil && $0.restart })
}

@Test func portGuessing() {
    #expect(ProjectDetector.guessPort(scriptBody: "vite") == 5173)
    #expect(ProjectDetector.guessPort(scriptBody: "vite serve --host") == 5173)
    #expect(ProjectDetector.guessPort(scriptBody: "next dev --turbo") == 3000)
    #expect(ProjectDetector.guessPort(scriptBody: "storybook dev") == 6006)
    #expect(ProjectDetector.guessPort(scriptBody: "node server.js --port=8081") == 8081)
    #expect(ProjectDetector.guessPort(scriptBody: "tsc -w") == nil)
}
