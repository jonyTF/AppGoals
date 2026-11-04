# AppGoals

Track one revenue goal with RevenueCat or Superwall, with shared home-screen and lock-screen widgets.

## Connect Superwall

1. Select **Superwall** during setup.
2. In Superwall's organization settings, create an organization API key with **charts:read** access to your app's project. Public `pk_` SDK keys cannot read metrics.
3. Enter that key and the numeric **Application ID** from your app's dashboard URL, then tap **Test & Save**.

AppGoals validates the connection before saving the key in Keychain. Existing RevenueCat connections, goals, and cached metrics continue working after upgrading. To change providers, disconnect in Settings and connect the other provider; disconnecting clears the current goal and cached metrics.

Superwall metrics come from the [Charts V2 API](https://api.superwall.com/docs):

| Metric | Definition |
| --- | --- |
| MRR | Latest monthly recurring revenue, in USD |
| Revenue | Gross revenue over 28 UTC calendar days including today, before refunds, taxes, and fees |
| Active Subscriptions | Latest active paid subscription count |
| New Subs Today | Paid starts in the current UTC day, including trial conversions and intro offers |

These use production data for the selected application. Configure [Revenue Tracking](https://superwall.com/docs/dashboard/dashboard-settings/overview-settings-revenue-tracking) in Superwall so subscription and revenue data are available. Other RevenueCat metrics and its resubscription toggle are not exposed for Superwall. Both app and widget use the same client; failed refreshes retain the last successful snapshot.

## Verification

Run API and persistence tests on macOS with `swift test`.

Build both iOS targets:

```sh
xcodebuild -project AppGoals/AppGoals.xcodeproj -scheme AppGoals \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```
