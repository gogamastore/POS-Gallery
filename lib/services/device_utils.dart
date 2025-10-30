String _firstAvailable(dynamic device, List<String> keys) {
  if (device == null) return '';
  try {
    if (device is Map) {
      for (final k in keys) {
        if (device.containsKey(k) && device[k] != null)
          return device[k].toString();
      }
      return '';
    }

    final dyn = device as dynamic;
    for (final k in keys) {
      try {
        switch (k) {
          case 'name':
            if (dyn.name != null) return dyn.name.toString();
            break;
          case 'localName':
            if (dyn.localName != null) return dyn.localName.toString();
            break;
          case 'deviceName':
            if (dyn.deviceName != null) return dyn.deviceName.toString();
            break;
          case 'productName':
            if (dyn.productName != null) return dyn.productName.toString();
            break;
          case 'id':
            if (dyn.id != null) return dyn.id.toString();
            break;
          case 'address':
            if (dyn.address != null) return dyn.address.toString();
            break;
          case 'deviceId':
            if (dyn.deviceId != null) return dyn.deviceId.toString();
            break;
          case 'serialNumber':
            if (dyn.serialNumber != null) return dyn.serialNumber.toString();
            break;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return '';
}

String getDeviceName(dynamic device) {
  final v = _firstAvailable(device, [
    'name',
    'localName',
    'deviceName',
    'productName',
    'id',
    'address',
    'deviceId'
  ]);
  return v.isNotEmpty ? v : 'Unknown Device';
}

String getDeviceAddress(dynamic device) {
  final v =
      _firstAvailable(device, ['address', 'id', 'deviceId', 'serialNumber']);
  return v.isNotEmpty ? v : 'No Address';
}
