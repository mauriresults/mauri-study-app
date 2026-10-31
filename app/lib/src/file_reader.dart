import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'models.dart';

/// Metadata is provided by our independent API; no website URLs are used.
class FileDetailsScreen extends StatefulWidget {
  final Resource resource;
  final String apiUrl;
  final bool french, initiallyFavorite;
  final String? localPath;
  final Future<String?> Function() onDownload;
  final Future<void> Function() onFavorite;
  const FileDetailsScreen({
    required this.resource, required this.apiUrl, required this.french,
    required this.initiallyFavorite, required this.localPath,
    required this.onDownload, required this.onFavorite, super.key,
  });
  @override
  State<FileDetailsScreen> createState() => _FileDetailsScreenState();
}

class _FileDetailsScreenState extends State<FileDetailsScreen> {
  late bool favorite = widget.initiallyFavorite;
  late String? localPath = widget.localPath;
  bool downloading = false;
  String t(String ar, String fr) => widget.french ? fr : ar;

  Future<void> download() async {
    if (downloading || localPath != null) return;
    setState(() => downloading = true);
    try {
      final saved = await widget.onDownload();
      if (mounted && saved != null) {
        setState(() => localPath = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('تم حفظ الملف دون إنترنت', 'Document enregistré hors ligne'))),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> toggleFavorite() async {
    await widget.onFavorite();
    if (mounted) setState(() => favorite = !favorite);
  }

  void preview() {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FileReaderScreen(
      title: widget.resource.display(widget.french),
      apiUrl: widget.apiUrl,
      localPath: localPath,
      french: widget.french,
      onDownload: widget.onDownload,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.resource;
    return Scaffold(
      appBar: AppBar(title: Text(t('تفاصيل الملف', 'Détails du document'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Icon(Icons.picture_as_pdf_outlined,
          color: Theme.of(context).colorScheme.primary, size: 56),
        const SizedBox(height: 18),
        Text(item.display(widget.french),
          style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('${item.typeLabel(widget.french)} · ${humanSize(item.size)}'
            '${item.examYear == null ? '' : ' · ${item.examYear}'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        FilledButton.icon(key: const ValueKey('detail-preview'),
          onPressed: preview, icon: const Icon(Icons.visibility_outlined),
          label: Text(t('مشاهدة الآن', 'Voir maintenant'))),
        const SizedBox(height: 12),
        OutlinedButton.icon(key: const ValueKey('detail-download'),
          onPressed: downloading || localPath != null ? null : download,
          icon: Icon(localPath == null ? Icons.download_outlined : Icons.offline_pin_rounded),
          label: Text(localPath == null
            ? t('تنزيل للاستخدام دون إنترنت', 'Télécharger pour lire hors ligne')
            : t('الملف محفوظ على الجهاز', 'Document enregistré sur l’appareil'))),
        const SizedBox(height: 12),
        TextButton.icon(key: const ValueKey('detail-favorite'),
          onPressed: toggleFavorite,
          icon: Icon(favorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded),
          label: Text(favorite
            ? t('إزالة من المفضلة', 'Retirer des favoris')
            : t('إضافة إلى المفضلة', 'Ajouter aux favoris'))),
      ]),
    );
  }
}

/// Online preview uses HTTP Range requests and does not add a permanent
/// download to the user's library. Offline saving is an explicit separate action.
class FileReaderScreen extends StatefulWidget {
  final String title, apiUrl;
  final String? localPath;
  final bool french;
  final Future<String?> Function() onDownload;
  const FileReaderScreen({
    required this.title, required this.apiUrl, required this.localPath,
    required this.french, required this.onDownload, super.key,
  });
  @override
  State<FileReaderScreen> createState() => _FileReaderScreenState();
}

class _FileReaderScreenState extends State<FileReaderScreen> {
  final PdfViewerController controller = PdfViewerController();
  late String? savedPath = widget.localPath;
  bool loading = true, failed = false, downloading = false;
  int attempt = 0;
  String t(String ar, String fr) => widget.french ? fr : ar;

  void retry() => setState(() {
    attempt++;
    loading = true;
    failed = false;
  });

  Future<void> download() async {
    if (downloading || savedPath != null) return;
    setState(() => downloading = true);
    try {
      final path = await widget.onDownload();
      if (!mounted) return;
      if (path != null) {
        setState(() => savedPath = path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('الملف محفوظ للاستخدام دون إنترنت', 'Disponible hors ligne')),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('فشل التنزيل، يمكنك إعادة المحاولة', 'Téléchargement échoué, réessayez')),
        ));
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> choosePage() async {
    if (!controller.isReady || controller.pageCount < 1) return;
    final input = TextEditingController(text: '${controller.pageNumber ?? 1}');
    final number = await showDialog<int>(context: context, builder: (dialog) => AlertDialog(
      title: Text(t('انتقل إلى صفحة', 'Aller à la page')),
      content: TextField(
        key: const ValueKey('reader-page-input'),
        controller: input,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: '1 – ${controller.pageCount}'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('إلغاء', 'Annuler'))),
        FilledButton(onPressed: () => Navigator.pop(dialog, int.tryParse(input.text)),
          child: Text(t('انتقال', 'Aller'))),
      ],
    ));
    input.dispose();
    if (number != null && number > 0 && number <= controller.pageCount && mounted) {
      await controller.goToPage(pageNumber: number);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      maxImageBytesCachedOnMemory: 24 * 1024 * 1024,
      onViewerReady: (_, _) {
        if (mounted) setState(() => loading = false);
      },
      onDocumentLoadFinished: (_, succeeded) {
        if (mounted && !succeeded) setState(() { failed = true; loading = false; });
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(key: const ValueKey('reader-page'), onPressed: choosePage,
            tooltip: t('الانتقال إلى صفحة', 'Aller à la page'),
            icon: const Icon(Icons.find_in_page_outlined)),
          IconButton(key: const ValueKey('reader-download'),
            onPressed: savedPath == null && !downloading ? download : null,
            tooltip: t('تنزيل للاستخدام دون إنترنت', 'Télécharger hors ligne'),
            icon: Icon(savedPath != null ? Icons.offline_pin_rounded : Icons.download_outlined)),
        ]),
      body: Stack(children: [
        if (!failed) Positioned.fill(
          child: savedPath != null
            ? PdfViewer.file(savedPath!, key: ValueKey('reader-local-$attempt'),
              controller: controller, params: params)
            : PdfViewer.uri(Uri.parse(widget.apiUrl), key: ValueKey('reader-online-$attempt'),
              controller: controller, params: params,
              preferRangeAccess: true, useProgressiveLoading: true,
              timeout: const Duration(seconds: 40))),
        if (loading && !failed) const Center(child: CircularProgressIndicator()),
        if (failed) Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text(t('تعذر عرض الملف. تحقق من الإنترنت ثم أعد المحاولة.',
              'Impossible de lire le document. Vérifiez la connexion.'),
              textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh),
              label: Text(t('إعادة المحاولة', 'Réessayer'))),
          ]))),
      ]),
    );
  }
}
