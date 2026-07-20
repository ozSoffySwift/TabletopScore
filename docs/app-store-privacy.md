# App Store Connect — privacy answers

Fill-in guide for the **App Privacy** section of App Store Connect. These
answers were derived from an audit of the source, not from assumption, and they
match `TabletopScore/PrivacyInfo.xcprivacy` and
[the published policy](https://ozsoffyswift.github.io/TabletopScore/privacy.html).
Keep all three in sync — Apple cross-checks the manifest against these answers.

## Privacy policy URL

```
https://ozsoffyswift.github.io/TabletopScore/privacy.html
```

Hosted on GitHub Pages from `docs/` on `main`, deliberately **not** on the
content server — an App Store listing must not break if that VM goes away.

## What the app actually collects

Audited from `TabletopScore/App/AnalyticsService.swift`. When the user leaves
"Share anonymous usage data" on, each event contains exactly:

| Field | Value |
|---|---|
| `type` | `game_opened` \| `play_started` \| `playlist_completed` |
| `gameId` / `playlistId` / `trackId` | catalog slug, e.g. `gloomhaven` |
| `anonDeviceId` | random UUID generated on first launch, stored in UserDefaults |
| `ts` | ISO-8601 timestamp |

No accounts, no IDFA, no location, no contacts, no third-party SDKs (Apple
frameworks only).

## Questionnaire answers

**"Do you or your third-party partners collect data from this app?"** → **Yes**

Then declare exactly two data types:

### 1. Identifiers → Device ID
| Question | Answer |
|---|---|
| Used for tracking? | **No** |
| Linked to the user's identity? | **No** |
| Purpose | **Analytics** |

> Rationale: `anonDeviceId` is a random, app-generated install identifier — not
> the IDFA and not derived from hardware. It is declared conservatively under
> Device ID because it distinguishes installs. There are no accounts, so it
> cannot be linked to an identity. Deleting the app discards it permanently.

### 2. Usage Data → Product Interaction
| Question | Answer |
|---|---|
| Used for tracking? | **No** |
| Linked to the user's identity? | **No** |
| Purpose | **Analytics** |

> Rationale: which games/playlists were opened or played.

### Do **not** declare
Contact info, health, financial, location, contacts, user content, search
history, browsing history, purchases, diagnostics, or "Other data" — none are
collected.

## Tracking / ATT

**"Does this app use data for tracking?"** → **No.**

The app has no IDFA access, no `AppTrackingTransparency` prompt, and shares
nothing with data brokers or advertisers. `NSPrivacyTracking` is `false` in the
manifest, and `NSPrivacyTrackingDomains` is empty. These must stay consistent.

## Two things to know before you submit

**1. Server logs contain IP addresses.** The app streams audio and artwork from
its own server, and nginx records the IP for every request. That is normal
server operation and is disclosed in the policy, but note it happens *regardless
of the analytics toggle* — turning analytics off stops the events above, not the
content requests. Apple's privacy labels cover data the app collects and sends,
so this does not add a label category, but the disclosure belongs in the policy
(it is there).

**2. The analytics toggle defaults to ON.** That is opt-*out*. Under GDPR,
analytics on EU users generally requires prior consent (opt-*in*), and a default-on
toggle is a weak basis for it. Options, cheapest first:
- Default the toggle to **off** (`AppSettings.hideClassicalMusic` pattern —
  change the `?? true` default for `shareAnonymousUsage` to `?? false`).
- Show a one-time consent prompt on first launch.
- Keep as-is and accept the risk — defensible given the data is genuinely
  anonymous and never leaves your own server, but it is a risk, not a
  non-issue.

## If advertising is added later

Ads change all of this. An ad SDK typically collects identifiers and may
constitute tracking, which would mean: new data types in the labels, likely an
ATT prompt, `NSPrivacyTracking` set to `true`, tracking domains listed, the
third-party SDK's own privacy manifest bundled, and a policy update. Do this
*before* shipping the ad-enabled version, not after.
