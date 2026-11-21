/// Hosts the app is willing to open from a server-supplied URL.
///
/// The device-code sheet tells the user to trust the page it opens, so a URL
/// that came over the network (and could have been swapped on the way) is
/// only opened when it is HTTPS on GitHub.
const _trustedHosts = {'github.com'};

/// Returns [raw] as a [Uri] when it is an `https://github.com/...` URL,
/// otherwise `null`.
Uri? trustedGithubUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme != 'https') return null;
  if (!_trustedHosts.contains(uri.host.toLowerCase())) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}
