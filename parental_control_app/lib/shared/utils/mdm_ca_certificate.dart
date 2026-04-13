import 'dart:io';
import 'dart:typed_data';

import 'android_parental_control_channel.dart';

/// Default URL on `mdm.healthkart.com` (override with `--dart-define=PARENTAL_CA_CERT_URL=...`).
const String kParentalCaCertUrl = String.fromEnvironment(
  'PARENTAL_CA_CERT_URL',
  defaultValue: 'https://mdm.healthkart.com/parental/filtering-ca.crt',
);

enum MdmCaInstallOutcome {
  ok,
  notAndroid,
  badStatus,
  emptyBody,
  writeFailed,
  installUiFailed,
  networkError,
}

String mdmCaInstallOutcomeMessage(MdmCaInstallOutcome o) {
  switch (o) {
    case MdmCaInstallOutcome.ok:
      return 'Complete the certificate steps on the next screen. Choose a user CA / VPN & apps credential if asked.';
    case MdmCaInstallOutcome.notAndroid:
      return 'Certificate install is only supported on Android from this screen.';
    case MdmCaInstallOutcome.badStatus:
      return 'Could not download the certificate (server error). Check MDM_PARENTAL_CA_CERT on mdm-server or your network.';
    case MdmCaInstallOutcome.emptyBody:
      return 'The certificate file from the server was empty.';
    case MdmCaInstallOutcome.writeFailed:
      return 'Could not save the certificate on this device.';
    case MdmCaInstallOutcome.installUiFailed:
      return 'Downloaded. Open Security settings and install the CA manually, or try again.';
    case MdmCaInstallOutcome.networkError:
      return 'Network error while downloading. Check https://mdm.healthkart.com is reachable.';
  }
}

/// Downloads the public CA from MDM and opens Android’s certificate installer.
Future<MdmCaInstallOutcome> downloadAndInstallParentalCaFromMdm() async {
  if (!Platform.isAndroid) return MdmCaInstallOutcome.notAndroid;

  final uri = Uri.parse(kParentalCaCertUrl);
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    if (resp.statusCode != 200) {
      return MdmCaInstallOutcome.badStatus;
    }
    final bytes = await _readAllBytes(resp);
    if (bytes.isEmpty) return MdmCaInstallOutcome.emptyBody;

    final dir = Directory.systemTemp;
    final file = File(
      '${dir.path}${Platform.pathSeparator}parental_filtering_ca_${DateTime.now().millisecondsSinceEpoch}.crt',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      return MdmCaInstallOutcome.writeFailed;
    }

    final opened = await androidInstallUserCaCertificate(file.absolute.path);
    return opened ? MdmCaInstallOutcome.ok : MdmCaInstallOutcome.installUiFailed;
  } catch (_) {
    return MdmCaInstallOutcome.networkError;
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> _readAllBytes(HttpClientResponse response) async {
  final b = BytesBuilder(copy: false);
  await for (final chunk in response) {
    b.add(chunk);
  }
  return b.takeBytes();
}
