# App Store Connect Copy — Casual Contacts

Drafted in the same voice as `docs/privacy.html` — sober, craft-driven, no hype. Edit before pasting into App Store Connect.

Each section is field-named to match App Store Connect exactly. Character counts in parentheses — Apple enforces these as hard limits, so the drafts below stay slightly under so you have room to tweak.

---

## App Information

### Name (max 30 chars)
```
Casual Contacts
```
(15 chars)

### Subtitle (max 30 chars)
```
For the people you just met
```
(27 chars)

Alternates if you'd rather different framing:
- `A pocket diary for new faces` (28)
- `Remember someone you just met` (29)
- `A short memory of who you met` (29)

### Primary Category
**Productivity**
*Or: Lifestyle. Productivity tends to surface higher in casual-contact-list searches; Lifestyle attracts a slightly different audience but signals craft. Pick one.*

### Secondary Category
**Lifestyle** (or Utilities)

---

## Promotional Text (max 170 chars, swappable without re-review)

```
Quick captures of the people you only ever meet once. A first name, where you were, what they were like. Nothing more, nothing less.
```
(144 chars)

---

## Description (max 4000 chars)

```
Casual Contacts is a private, on-device record of the people you've just met — the barista who knew the order, the stranger on the next bench, the friend of a friend at the party. Names and faces you'd otherwise forget by tomorrow.

It works the way memory does. You jot a first name, an association, maybe a photo, and the app captures the rest — the time of day, the moon phase, the place. Each entry becomes a small, distinctive card you'll recognize again, even months later.

Why it's different
———————————
• Local-first. There's no account, no server, no cloud. Your records live on your device, where they belong.
• No analytics, no tracking, no advertising SDKs. The app doesn't watch you, and it doesn't sell what it doesn't have.
• Designed for memory, not contacts management. Casual Contacts isn't a CRM — it's a sketchbook.

How it works
———————————
• Tap +. Type a first name. Add an association ("met at Polly's birthday", "shared a cab from JFK"), and optionally a photo or a place.
• The app records the moment around it: time of day, moon phase, where you stood. Each card paints itself from those details, so no two records look alike.
• Browse later by name, by date, or by distance from where you are now. Tap a card to see the full memory.

Built for moments, not appointments
———————————
You don't write down the friend-of-a-friend in your phone's Contacts app. You don't text them. But weeks later you wish you remembered who they were. Casual Contacts is for that — the in-between.

Privacy
———————————
Everything you enter stays on your device. No account, no cloud sync, no third parties. Read the full policy at casualcontacts.app/privacy.
```
(~1640 chars — leaves ~2300 room to add features later)

---

## Keywords (max 100 chars total, comma-separated, no spaces between)

```
contacts,casual,memory,party,met,friend,journal,diary,quick,faces,strangers,people,personal
```
(100 chars)

*Tips: avoid the word "Casual" or "Contacts" — they're already in your title and re-using them wastes characters. Avoid plurals when the singular is also indexed (Apple's algorithm matches both). Above leans toward search intent ("I just met someone, want to remember"). Swap "diary" or "faces" for niche-fit words after a few weeks of looking at App Store Connect's "Search" analytics.*

---

## Support URL

```
https://casualcontacts.app/support
```

*Could just be `mailto:hello@therealadammork.com` for v1 if you don't want to host a support page yet — Apple accepts mailto: URLs.*

---

## Marketing URL (optional)

```
https://casualcontacts.app
```

---

## Privacy Policy URL (required)

```
https://casualcontacts.app/privacy
```

---

## Screenshots

Upload from `Screenshots/{light,dark}/`. Apple wants the **raw** PNGs (1320×2868, no frame) — App Store Connect renders its own device frame. Pick **one appearance** to upload (most apps go with dark for a more dramatic feel; Casual Contacts' visual identity is dark-first per the spec, so dark is the natural pick).

Order to upload:
1. `02-list.png` — leads with the visual hook (cards in proximity-grouped list)
2. `04-detail-iris.png` — the centerpiece visual, the medium-card design
3. `01-empty-state.png` — sets the tone, "add the first person"
4. `05-create-step1.png` — shows the input UX
5. `06-create-step2.png` — input UX with a zodiac selected
6. `03-list-sort-open.png` — flexes the sort-by-distance feature

*App Store Connect lets you reorder; tweak after upload if a different order tells the story better.*

---

## What's New (per release, 4000 chars)

### v1.0 (initial release)
```
First release. Capture the people you just met — first names, associations, places, moments — without giving up your privacy.
```
(127 chars)

---

## Age Rating Questionnaire — answers

The questionnaire is ~12 yes/no items. For Casual Contacts, every answer is **None** / **No**:
- No violence, no sexual content, no profanity, no alcohol/drugs/tobacco, no horror/fear themes, no gambling, no contests, no medical info, no unrestricted web access, no user-generated content visible to others (records are local-only), no social-network features, no in-app purchases.

Result: **4+** rating.

---

## App Privacy — "Data Used to Track You"

**No data is used to track the user.**

## App Privacy — "Data Linked to You"

**No data linked to you.**

## App Privacy — "Data Not Linked to You"

**No data collected.**

(All three because the app is local-first; Apple's questionnaire confirms this and you'll get the "Data Not Collected" badge.)

---

## Notes for paste-and-edit

- **App Store description Bullet character:** Apple strips fancy bullets in some preview contexts. The `———————————` separators above are em-dashes, which render reliably. If you want true bullets, use `•` (already used inside sections).
- **Localization:** v1 ships English (US) only. If you decide to localize later, German / French / Spanish / Japanese are the highest-leverage adds for an indie app.
- **Reviewer notes:** when you Submit, Apple may ask "what's the test account?" — answer "no account required, app is local-only." That's accepted.
