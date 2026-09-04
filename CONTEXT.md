# Iam - hero

A private family storybook: parents write personalised picture books for their
children on their own devices, with an optional PC at home doing the writing
and drawing. One context; this file is its glossary, and nothing else.

## Language

### The family

**Hero**:
The child a story is about, as the story sees them: name, Girl/Boy choice, and
the face the pictures are drawn from.
_Avoid_: character, protagonist, user

**Child profile**:
One child's private record on a device: name, birth date, photo, saved colour,
story preferences, Kingdom decoration, reading settings, and the stories they
finished.
_Avoid_: account, user, kid

**Hero face**:
The one way a child's photo (or, failing that, their initial) is drawn on any
screen, ringed in their own accent.
_Avoid_: avatar, thumbnail

**Kingdom**:
A child's own decorated corner of the app: castle style, frame, backdrop and
favourite symbol, plus their reading rewards.
_Avoid_: dashboard, profile page

**Reading badge**:
A count-based reward for stories finished on this device (1, 5, 10, 25). No
streaks, no dates.
_Avoid_: achievement, trophy, streak

### Parents

**Parent-gated action**:
One parent-only action on a story — deleting it, making its pictures, writing a
story file, reading one back, changing its collections, saving a PDF — run as
one sequence: the PIN gate, the parent's confirmation, the action itself, then
the one sentence it leaves behind.
_Avoid_: flow, handler, protected action

### Stories

**Story**:
One finished picture book: a request, a title, pages of prose with a scene each,
and whether a parent has approved it.
_Avoid_: book (in code), tale, content

**Story request**:
What a parent asks for: the hero, a theme, a moral, the page count, the
illustration style and the language.
_Avoid_: prompt (that is the bridge's word for the model text), form

**Story request draft**:
The request a parent is still tapping together, including what a chosen hero
seeds and whether it can be sent yet.
_Avoid_: form state

**Draft** / **Approved**:
A story's review status. Children see only approved stories; drafts wait for a
parent.
_Avoid_: pending, published

**Collection**:
A parent-chosen label on a story, used as a shelf filter.
_Avoid_: tag, folder, category

**Keep reading**:
The newest approved story on the active child's shelf that this device has not
recorded as finished. Nothing about a reading position is stored.
_Avoid_: continue, resume, bookmark

**Story artwork**:
What is drawn for a story's cover or a page: the drawn picture when the PC has
made one, otherwise the placeholder colours for its style and hero.
_Avoid_: thumbnail, gradient, illustration (reserved for drawn pictures)

**Illustration**:
A picture drawn by the PC for one page, identified by the bridge.
_Avoid_: image, artwork (see above)

**Page spread**:
One open page as the reader draws it: its picture and its prose, stacked on a
phone and side by side on a wider screen. Everything a spread needs arrives as
one value, so a page can be drawn without a reader around it.
_Avoid_: page view, slide, layout

### The shelf and Home

**Shelf**:
One child's approved stories, as the Library shows them.
_Avoid_: library (that is the whole device's collection), list

**Shelf view**:
Everything one build of the shelf shows, decided from whose shelf it is, the
search, and the filter.
_Avoid_: state, view model

**Shelf filter**:
Which books of a shelf are asked for: all, favourites, or one collection.
_Avoid_: tab, category

**Home view**:
Everything Home decides from the family's stored state at one moment: the keep
reading book, the shelf strip, drafts waiting, and which greeting line is true.
_Avoid_: state, view model

### Persistence

**Library**:
Everything a device has stored for the family: profiles, stories, locale, and
the active child.
_Avoid_: database, store, app state (in prose)

**Library transaction**:
One change to the library that is written first and published to the screens
only once the write succeeded. The only way a feature changes the library.
_Avoid_: commit, save, update

**Backup**:
A password-encrypted file of the whole library.
_Avoid_: export (that is a single story or a PDF), archive

**Story file**:
A password-encrypted file carrying one story, for another device to import.
_Avoid_: share, export

**Encrypted file flow**:
The one sequence a backup or a story file travels through: pick or name a file,
ask for the password, decode or encode, report a typed failure.
_Avoid_: import/export service

### The PC

**Bridge**:
The service on the family PC that owns the master library, pairs devices,
writes stories with Ollama and draws them with ComfyUI.
_Avoid_: server, backend, API

**Master library**:
The bridge's copy of every profile and story, from which paired devices sync.
_Avoid_: database, remote library

**Paired device**:
A phone, tablet or browser the bridge has issued a bearer token to, named by the
parent at pairing time.
_Avoid_: client, session

**Pairing**:
The ceremony that turns a six-digit code shown on the PC into a device token.
_Avoid_: login, registration

**Removing a device**:
Ending another paired device's access from the app, so its next call to the
bridge is refused. Distinct from _forgetting this device_, which deletes only
the token this device holds and leaves the PC's list alone.
_Avoid_: revoking, unpairing, deleting a device

**Sync**:
One device taking what is new in the master library, and only then reporting
back what it took.
_Avoid_: download, refresh, fetch

**Job**:
One request the bridge is working through: a story generation or the
illustration of a story's pages, queued, running, then settled.
_Avoid_: task, request (in the bridge), operation

**GPU tenant**:
Whichever of the two local services (Ollama, ComfyUI) holds the PC's single
graphics card right now, and has to let go before the other may start.
_Avoid_: lease holder, lock owner

**Outline**:
The story plan the model writes first: title, one beat per page, the hero's
appearance line, the lesson moment and the turn page, approved before any page
is written.
_Avoid_: plan (in code), skeleton

**Lesson moment**:
The one sentence in an outline naming the concrete situation where the hero
faces the parent's moral. The situation, never the moral restated.
_Avoid_: theme, message, takeaway

**Turn page**:
The page of an outline where the hero chooses the lesson. Always in the middle
of the book: after page 1, before the last page.
_Avoid_: climax, twist
