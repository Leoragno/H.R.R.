/// Sceglie un elemento da [options] in modo stabile per la coppia
/// ([seed], [salt]) — stesso seed+salt restituisce sempre lo stesso
/// elemento (niente flicker tra rebuild), ma varia tra occorrenze diverse.
/// Stessa formula usata in notification_presentation.dart (`_pick`),
/// promossa qui per essere riusata anche fuori da quella feature.
T pickDeterministic<T>(String seed, String salt, List<T> options) =>
    options[(seed + salt).hashCode.abs() % options.length];
