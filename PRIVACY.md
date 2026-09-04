# Privacy Policy for GPS Server for iOS

Last updated: 2026-08-22

GPS Server for iOS is a free, open-source application that shares the iPhone's
current location with a client device over the user's local network.

## Data Handling

The app does not collect, store, sell, or transmit personal data to the
developer, analytics providers, or advertising networks. It does not require an
account and does not use tracking or advertising SDKs.

When you start the server, the app reads your location and sends it directly to
clients connected to the local network you choose, such as your personal hotspot
or Wi-Fi network. The app does not upload location data to an internet server.

The app uses local network access so the client device can connect to the server
on your iPhone. Background location is used only while the server is active, so
location sharing can continue when the screen is locked.

## Diagnostic Logs

Diagnostic events are kept in memory on your device. You may explicitly export
and share a log file. Precise coordinates are excluded from exported logs by
default and are included only when you enable the corresponding option in the
app. Review exported logs before sharing them.

## Your Choices

You can stop the server at any time. You can change or revoke location and
local network permissions in iOS Settings. You can clear the in-app diagnostic
log buffer at any time.

## Contact

For questions about this policy, please open an issue in the project's GitHub
repository: https://github.com/taylandaribaev/gnss-server-ios
