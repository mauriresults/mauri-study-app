import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'src/models.dart';
import 'src/storage.dart';

// Independent public Cloudflare API; override with --dart-define=API_BASE_URL=...
const apiBase = String.fromEnvironment('API_BASE_URL',defaultValue:'https://mauri-study-app-api.mauri-study-app.workers.dev');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MauriStudyApp());
}

class MauriStudyApp extends StatelessWidget {
  const MauriStudyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'دروسي موريتانيا',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1252A3)),scaffoldBackgroundColor:const Color(0xFFF6F8FB)),
    home:const StudyHome(),
  );
}

class StudyHome extends StatefulWidget {
  const StudyHome({super.key});
  @override State<StudyHome> createState()=>_StudyHomeState();
}

class _StudyHomeState extends State<StudyHome> {
  late final AppStorage store;
  Catalog? catalog;
  Map<int,String> local={};
  bool french=false, busy=false;
  int tab=0;
  String? level,track,subject;
  String query='';
  int? downloading;
  double progress=0;
  String? status;

  @override void initState(){super.initState(); store=AppStorage(apiBase);_boot();}
  @override void dispose(){store.dispose();super.dispose();}

  Future<void> _boot() async {
    try {
      await store.open();
      final cached=await store.cachedCatalog();
      final files=await store.downloaded();
      if(!mounted)return;
      setState((){catalog=cached;local=files;});
      if(apiBase.isNotEmpty) {
        await _refresh();
      } else {
        setState(()=>status='لم يُضبط عنوان API بعد. الملفات المحفوظة تعمل دون إنترنت.');
      }
    }catch(e){if(mounted)setState(()=>status='خطأ في التهيئة: $e');}
  }

  Future<void> _refresh() async {
    if(busy)return;
    setState((){busy=true;status=null;});
    try{
      final updated=await store.sync();
      final files=await store.downloaded();
      if(mounted)setState((){catalog=updated;local=files;status=null;});
    }catch(_){
      if(mounted) {
        setState(()=>status=catalog==null
        ?'تعذر الاتصال بالمكتبة. اتصل بالإنترنت للمزامنة الأولى.'
        :'أنت الآن في وضع عدم الاتصال. يمكنك فتح المواد المحفوظة.');
      }
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _openFile(Resource r) async {
    final path=local[r.id];
    if(path!=null && await File(path).exists()){
      if(!mounted)return;
      await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PdfScreen(path:path,title:r.display(french))));
      return;
    }
    if(downloading!=null)return;
    if(apiBase.isEmpty){_notify('عنوان الخادم غير مهيأ');return;}
    setState((){downloading=r.id;progress=0;});
    try{
      final downloadedPath=await store.download(r,onProgress:(n,total){
        if(mounted)setState(()=>progress=total==0?0:n/total);
      });
      if(mounted){
        setState(()=>local[r.id]=downloadedPath);
        _notify(french?'Saved for offline use':'تم الحفظ للقراءة دون إنترنت');
        await Navigator.of(context).push(MaterialPageRoute(
          builder:(_)=>PdfScreen(path:downloadedPath,title:r.display(french)),
        ));
      }
    }catch(e){if(mounted)_notify('فشل التنزيل: $e');}
    finally{if(mounted)setState(()=>downloading=null);}
  }

  /// One-tap offline pack for current filters (level, track, subject or search).
  /// Show the expected space before transfer; do not download the entire 50 GB library.
  Future<void> _downloadMany(List<Resource> visible) async {
    if(downloading != null || visible.isEmpty) return;
    final missing=visible.where((r)=>!local.containsKey(r.id)).toList();
    if(missing.isEmpty){_notify(french?'All files are already saved':'كل الملفات محفوظة بالفعل');return;}
    final bytes=missing.fold<int>(0,(sum,r)=>sum+r.size);
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(french?'Download for offline use':'تحميل للدراسة دون إنترنت'),
      content:Text(french
        ?'Save ${missing.length} files (${humanSize(bytes)}) to this device?'
        :'هل تريد حفظ ${missing.length} ملفًا (${humanSize(bytes)}) على هاتفك؟'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(french?'Cancel':'إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(french?'Download':'تحميل')),
      ],
    ));
    if(approved!=true || !mounted)return;
    var succeeded=0;var failed=0;
    for(final r in missing){
      if(!mounted)break;
      setState((){downloading=r.id;progress=0;});
      try {
        final path=await store.download(r,onProgress:(n,total){
          if(mounted)setState(()=>progress=total==0?0:n/total);
        });
        if(mounted)setState(()=>local[r.id]=path);
        succeeded++;
      }catch(_){failed++;}
    }
    if(mounted){
      setState((){downloading=null;progress=0;});
      _notify(french?'Saved: $succeeded, failed: $failed':'تم حفظ $succeeded ملفًا، وتعذر تحميل $failed');
    }
  }

  void _notify(String s){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override Widget build(BuildContext context){
    final data=catalog;
    final tracks=data?.tracks.where((x)=>level==null||x.levelId==level).toList()??[];
    final subjects=data?.subjects.where((x)=>track==null? (level==null || tracks.any((t)=>t.id==x.trackId)) : x.trackId==track).toList()??[];
    final resources=(data?.resources??[]).where((r){
      if(tab==1 && !local.containsKey(r.id))return false;
      if(subject!=null && r.subjectId!=subject)return false;
      if(subject==null && !subjects.any((x)=>x.id==r.subjectId))return false;
      if(query.trim().isNotEmpty && !('${r.titleAr} ${r.titleFr} ${r.kind} ${r.examYear??''}').toLowerCase().contains(query.trim().toLowerCase()))return false;
      return true;
    }).toList();
    return Directionality(textDirection:french?TextDirection.ltr:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:Text(french?'Mes cours':'دروسي موريتانيا'),actions:[
        IconButton(tooltip:'Refresh',onPressed:busy?null:_refresh,icon:const Icon(Icons.refresh)),
        TextButton(onPressed:()=>setState(()=>french=!french),child:Text(french?'عربي':'FR')),
      ]),
      body:Column(children:[
        if(busy)const LinearProgressIndicator(minHeight:2),
        if(status!=null)MaterialBanner(content:Text(status!),actions:[TextButton(onPressed:_refresh,child:Text(french?'Réessayer':'إعادة المحاولة'))]),
        if(tab==0)...[
          Padding(padding:const EdgeInsets.fromLTRB(14,12,14,4),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:french?'Rechercher':'ابحث عن درس أو امتحان',border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))))),
          if(data!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Column(children:[
            _choose(french?'Niveau':'المستوى',level,data.levels,(v)=>setState((){level=v;track=null;subject=null;})),
            _choose(french?'Série':'الشعبة',track,tracks,(v)=>setState((){track=v;subject=null;})),
            _choose(french?'Matière':'المادة',subject,subjects,(v)=>setState(()=>subject=v)),
          ])),
          if(data!=null && resources.isNotEmpty)
            Padding(padding:const EdgeInsets.fromLTRB(14,2,14,8),child:OutlinedButton.icon(
              onPressed:downloading!=null?null:()=>_downloadMany(resources),
              icon:const Icon(Icons.download_for_offline_outlined),
              label:Text(french?'Télécharger la sélection (${resources.length})':'تحميل الملفات المعروضة (${resources.length})'),
            )),
        ],
        Expanded(child:data==null
          ?Center(child:Text(french?'Aucun catalogue disponible':'لا يوجد فهرس محفوظ بعد'))
          :resources.isEmpty
            ?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(french?'Aucun document disponible':'لا توجد ملفات في هذا القسم حتى الآن',textAlign:TextAlign.center)))
            :ListView.builder(itemCount:resources.length,itemBuilder:(context,i){
              final r=resources[i];final saved=local.containsKey(r.id);
              return Card(margin:const EdgeInsets.symmetric(horizontal:14,vertical:5),child:ListTile(
                leading:Icon(saved?Icons.offline_pin:Icons.picture_as_pdf,color:saved?Colors.green:const Color(0xFF1252A3)),
                title:Text(r.display(french),maxLines:2,overflow:TextOverflow.ellipsis),
                subtitle:Text('${r.typeLabel(french)}${r.examYear==null?'':' • ${r.examYear}'} • ${humanSize(r.size)}'),
                trailing:downloading==r.id
                  ?SizedBox(width:35,height:35,child:CircularProgressIndicator(value:progress>0?progress:null))
                  :Icon(saved?Icons.menu_book:Icons.download_outlined),
                onTap:()=>_openFile(r),
                onLongPress:saved?()=>_remove(r):null,
              ));
            }),
        ),
      ]),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(n)=>setState((){tab=n;if(n==1){level=null;track=null;subject=null;query='';}}),destinations:[
        NavigationDestination(icon:const Icon(Icons.school_outlined),label:french?'Bibliothèque':'المكتبة'),
        NavigationDestination(icon:const Icon(Icons.offline_pin_outlined),label:french?'Hors ligne':'دون إنترنت'),
      ]),
    ));
  }

  Widget _choose(String hint,String? selected,List<Node> nodes,ValueChanged<String?> onChanged){
    return Padding(padding:const EdgeInsets.only(bottom:5),child:DropdownButtonFormField<String>(
      key: ValueKey('${hint}_${selected ?? 'all'}'),
      initialValue:selected, isExpanded:true,
      decoration:InputDecoration(labelText:hint,isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:8),border:const OutlineInputBorder()),
      items:[DropdownMenuItem<String>(value:null,child:Text(french?'Tous':'الكل')),
        ...nodes.map((n)=>DropdownMenuItem(value:n.id,child:Text(n.display(french),overflow:TextOverflow.ellipsis)))],
      onChanged:onChanged,
    ));
  }

  Future<void> _remove(Resource resource) async{
    await store.remove(resource.id);
    if(mounted){setState(()=>local.remove(resource.id));_notify(french?'Removed':'تم حذف النسخة المحفوظة');}
  }
}

class PdfScreen extends StatefulWidget {
  final String path,title;
  const PdfScreen({required this.path,required this.title,super.key});
  @override State<PdfScreen> createState()=>_PdfScreenState();
}
class _PdfScreenState extends State<PdfScreen>{
  late final PdfControllerPinch controller;
  @override void initState(){super.initState();controller=PdfControllerPinch(document:PdfDocument.openFile(widget.path));}
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.title)),
    body:PdfViewPinch(controller:controller),
  );
}
