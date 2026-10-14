import Foundation

/// `input` as a GitHub repository "owner/repo", trimmed of whitespace, or
/// `nil` when it is not one owner and one name, each made of letters,
/// digits, "-", "_", and ".", separated by one "/".
public func repositoryName(_ input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2,
          parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(isRepositoryCharacter) }) else { return nil }
    return trimmed
}

private func isRepositoryCharacter(_ character: Character) -> Bool {
    character.isASCII && (character.isLetter || character.isNumber || "-_.".contains(character))
}
