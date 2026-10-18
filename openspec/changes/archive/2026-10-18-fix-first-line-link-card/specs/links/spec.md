# Spec Delta

## MODIFIED Requirements

### Requirement: Preview card above a paragraph with a link
A note paragraph, a list title, or a list item that contains a web address SHALL show a preview card above its text once the page information for its first web address is available. Other web addresses in the same paragraph, title, or item MUST NOT add cards. A paragraph is the text between line breaks. In a note, the card MUST be as wide as the note's text area and follow the text as it wraps, scrolls, and resizes. A card MUST show fully inside the note's text area, also when its paragraph is the note's first one.

#### Scenario: Card above a note paragraph
- **WHEN** a note contains "see https://crunchyroll.com" and its page information is available
- **THEN** a card for crunchyroll.com shows directly above the line "see https://crunchyroll.com"

#### Scenario: Two links in one paragraph
- **WHEN** a note paragraph reads "apple.com or crunchyroll.com" and page information is available for both
- **THEN** one card, for apple.com, shows above the paragraph

#### Scenario: Links in two paragraphs
- **WHEN** a note has "apple.com" on its first line and "crunchyroll.com" on its third line
- **THEN** a card for apple.com shows above the first line and a card for crunchyroll.com shows above the third line

#### Scenario: Link on a note's first line
- **WHEN** the first thing the user types in an empty note is "apple.com" and its page information arrives
- **THEN** the card for apple.com shows fully at the top of the note, with no part of it above the note's text area, and the line "apple.com" shows directly below it

#### Scenario: Link removed from a note's first line
- **WHEN** a note's first paragraph shows a card and the user edits that paragraph so it has no web address
- **THEN** the card disappears and the first line moves back up to the top of the note

#### Scenario: Card in a list item
- **WHEN** a list item reads "buy at store.example.com" and its page information is available
- **THEN** a card for store.example.com shows above the item's text, and the item's check circle stays beside its text

#### Scenario: Link removed
- **WHEN** a note paragraph shows a card and the user edits the paragraph so it has no web address
- **THEN** the card disappears and the paragraph's text moves up to where the card was
