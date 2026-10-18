# links Specification

## Purpose

Lets the user keep web addresses in notes and lists as links: shown as links, opened in the browser with Cmd+click, and previewed at all times by a card above each paragraph or list row that has one.

## Requirements

### Requirement: Web addresses show as links
Every web address in note text, in a list's title, or in a list item SHALL show as a link: in the link color and underlined, in the font, size, and styles the text has otherwise. A web address is text that starts with "http://" or "https://", or a domain name with a known top-level domain, such as "apple.com" or "www.apple.com/mac", with an optional path. Email addresses, phone numbers, and other kinds of addresses MUST NOT show as links. Links MUST update as the user types, pastes, cuts, undoes, or redoes, without moving the caret or the selection. Links MUST NOT change the saved text or styles, the undo history, or the text that Copy puts on the pasteboard. Link formatting in pasted rich text MUST NOT make text a link; only text that is itself a web address shows as a link. A checked list item MUST show its links struck through, in the link color. The link color is blue (#1D4ED8) in light appearance and the system link color in dark appearance.

#### Scenario: Type an address in a note
- **WHEN** the user types "see https://apple.com/mac today" in a note
- **THEN** "https://apple.com/mac" shows in the link color and underlined, and the other words show as before

#### Scenario: Address without a scheme
- **WHEN** a list item's text is "buy at store.example.com"
- **THEN** "store.example.com" shows as a link

#### Scenario: Not a web address
- **WHEN** a note contains "mail me at ana@example.com"
- **THEN** no part of the text shows as a link

#### Scenario: Address edited into plain text
- **WHEN** a note shows "https://apple.com" as a link and the user deletes "https://apple.co", leaving "m"
- **THEN** no part of the text shows as a link

#### Scenario: Styles kept
- **WHEN** a note's web address is bold and the font setting changes to the system font at 18 points
- **THEN** the address shows bold, in the system font at 18 points, in the link color and underlined

#### Scenario: Pasted link with other text
- **WHEN** the user pastes a link from a web page whose visible text is "Read more"
- **THEN** "Read more" shows as plain note text, not as a link

#### Scenario: Links are not saved
- **WHEN** a note shows a link and the app is quit and launched again
- **THEN** the note's saved text is the same characters with the same styles, and the address shows as a link again

#### Scenario: Link color in light appearance
- **WHEN** the Mac uses light appearance and a note shows "https://apple.com"
- **THEN** "https://apple.com" shows in blue (#1D4ED8) and underlined

#### Scenario: Link color in dark appearance
- **WHEN** the Mac uses dark appearance and a note shows "https://apple.com"
- **THEN** "https://apple.com" shows in the system link color and underlined

### Requirement: Cmd+click opens a link
Clicking a link while holding Cmd SHALL open its address in the default web browser. An address without "http://" or "https://" MUST open with "http://" added. The click MUST NOT place the caret, select text, start editing a list row, or move the window. A click on a link without Cmd MUST behave as a click on any other text: it places the caret and edits. Cmd+click outside a link MUST behave as it does today. Cmd+click MUST work in notes and list rows whether or not they are being edited, and on the first click while Notely is not the active app.

#### Scenario: Open a link from a note
- **WHEN** the user holds Cmd and clicks "https://apple.com" in a note
- **THEN** the default browser opens https://apple.com
- **AND** the note's caret and selection do not change

#### Scenario: Open a link from a list item that is not being edited
- **WHEN** no list row has keyboard focus and the user holds Cmd and clicks a link in an item
- **THEN** the default browser opens the link
- **AND** the item does not start editing

#### Scenario: Plain click edits
- **WHEN** the user clicks a link in a note without holding Cmd
- **THEN** the caret moves to the clicked position in the link and no browser opens

#### Scenario: Address without a scheme opens
- **WHEN** the user Cmd+clicks "store.example.com"
- **THEN** the browser opens http://store.example.com

### Requirement: Pointer over a link
While Notely is the active app and the user holds Cmd with the pointer over a link, the pointer SHALL show as a pointing hand. Releasing Cmd or moving the pointer off the link MUST bring back the pointer that shows over text.

#### Scenario: Hold Cmd over a link
- **WHEN** the pointer rests on a link and the user presses Cmd
- **THEN** the pointer changes to a pointing hand

#### Scenario: Release Cmd
- **WHEN** the pointer shows a pointing hand over a link and the user releases Cmd
- **THEN** the pointer changes back to the text pointer

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

### Requirement: Card layout
A card SHALL show, from top to bottom: the page's image, the page's title in bold, the page's description in gray on at most 4 lines ending in "…" when longer, and a footer row with a link glyph, the site's domain, and the site's icon at the trailing edge. The image MUST fill the card's width at a 1.91:1 shape, cropped to fit. A missing description, or a missing site icon, MUST leave its place out of the card.

#### Scenario: Full card
- **WHEN** a page has an image, the title "Watch The Apothecary Diaries", a long description, and a site icon
- **THEN** the card shows the image, the title in bold, the first 4 lines of the description ending in "…", and a footer with a link glyph, "crunchyroll.com", and the site icon at the trailing edge

#### Scenario: No description
- **WHEN** a page has a title and an image but no description
- **THEN** the card shows the image, the title, and the footer, with no empty gap where the description would be

### Requirement: Compact card without an image
A page with a title but no image SHALL show a compact card: the title, the description, and the footer, with no image area.

#### Scenario: Page without an image
- **WHEN** a page has the title "Example Domain" and no image
- **THEN** the card shows "Example Domain" and the footer with "example.com", and no image area

### Requirement: No card until the page information arrives
While a page's information is loading, no card and no space for one SHALL show. When the information arrives, the card MUST appear and the text below it MUST move down to make room, without moving the caret or the selection within the text. When the page cannot be reached, answers with an error, or has no title, no card MUST show and no error message MUST show.

#### Scenario: Loading
- **WHEN** the user types "crunchyroll.com" and the page information has not arrived
- **THEN** the paragraph shows with no card above it

#### Scenario: Information arrives
- **WHEN** the page information for a paragraph's link arrives
- **THEN** the card appears above the paragraph and the caret stays at the same place in the text

#### Scenario: Offline
- **WHEN** the Mac has no network connection and a note contains "crunchyroll.com" with no stored page information
- **THEN** no card shows and no error message shows

### Requirement: When pages are requested
Notely SHALL request a page's information once its web address has stayed unchanged in a note, list title, or list item for about one second, and when a note or list showing it opens. Each address MUST be requested at most once at a time, however many notes and rows show it. An address without "http://" or "https://" MUST be requested with "https://".

#### Scenario: Typing an address
- **WHEN** the user types "crunchyroll.com" one character at a time and then stops typing
- **THEN** Notely requests only https://crunchyroll.com, about one second after the last keystroke

#### Scenario: Same address in two notes
- **WHEN** two open notes contain "apple.com" and its page information is not stored
- **THEN** Notely sends one request for it and both notes show the card when it arrives

### Requirement: Stored page information
Notely SHALL keep page information that arrived, including the image and site icon, on disk, and MUST show a card from it at once, without requesting the page again, in this and later sessions. A request that failed MUST NOT be kept: Notely MUST request that page again on the next launch, and not again in the same session.

#### Scenario: Relaunch
- **WHEN** a note showed a card for apple.com and Notely is quit and launched again
- **THEN** the card shows as soon as the note opens, without requesting apple.com

#### Scenario: Failed page retried on relaunch
- **WHEN** the request for a page failed and the user quits and relaunches Notely
- **THEN** Notely requests the page once more, and shows a card if the request succeeds

### Requirement: Click a card to open its link
A plain click on a card SHALL open its link in the default web browser, also while Notely is not the active app. The click MUST NOT place the caret, select text, or start editing a list row. The pointer MUST show as a pointing hand over a card.

#### Scenario: Open from a card
- **WHEN** the user clicks the card above "see crunchyroll.com"
- **THEN** the default browser opens https://crunchyroll.com and the note's caret and selection do not change

#### Scenario: Pointer over a card
- **WHEN** the pointer rests over a card
- **THEN** the pointer shows as a pointing hand

### Requirement: Cards are display only
Cards MUST NOT change a note's or list's saved text or styles, the undo history, or the text that Copy puts on the pasteboard. The caret MUST NOT move into or stop at a card: moving the caret up from a paragraph's first line MUST go to the line above the card.

#### Scenario: Copy around a card
- **WHEN** the user selects two paragraphs, the second with a card, and copies
- **THEN** the pasteboard holds only the two paragraphs' text

#### Scenario: Saved text unchanged
- **WHEN** a note shows cards and the app is quit and launched again
- **THEN** the note's saved text is the same characters with the same styles as before the cards showed
