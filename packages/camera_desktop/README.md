# camera_desktop (vendored, macOS only)

A copy of [camera_desktop 2.0.0](https://pub.dev/packages/camera_desktop)
(MIT, see LICENSE) with its Linux and Windows platform entries removed.

It supplies the macOS implementation of the `camera` package. The upstream
package also registers for Windows, which Flutter rejects alongside
`camera_windows` ("conflicting direct dependency implementations"), so only
the macOS half is kept here and Windows keeps using `camera_windows`.
