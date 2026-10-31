import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'file_reader.dart';
import 'models.dart';
import 'storage.dart';
import 'ui.dart';

const apiBase = String.fromEnvironment('API_BASE_URL',defaultValue:'https://mauri-study-app-api.mauri-study-app.workers.dev');

class MauriStudyApp extends StatefulWidget {
  final AppStorage? storage;
  final bool syncOnStart;
  const MauriStudyApp({this.storage,this.syncOnStart=true,super.key});
  @override
  State<MauriStudyApp> createState()=>_MauriStudyAppState();
}

class _MauriStudyAppState extends State<MauriStudyApp> {
  late final AppStorage store;
  UserPreferences preferences = const UserPreferences();
  @override
  void initState(){super.initState();store=widget.storage??AppStorage(apiBase);}
  @override
  void dispose(){unawaited(store.dispose());super.dispose();}
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'Mauri student',debugShowCheckedModeBanner:false,
    locale:Locale(preferences.french?'fr':'ar'),supportedLocales:const [Locale('ar'),Locale('fr')],
    localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
    theme:studyTheme(Brightness.light),darkTheme:studyTheme(Brightness.dark),
    themeMode:preferences.theme=='dark'?ThemeMode.dark:preferences.theme=='light'?ThemeMode.light:ThemeMode.system,
    home:StudyHome(store:store,preferences:preferences,syncOnStart:widget.syncOnStart,
      onPreferencesChanged:(value){if(mounted)setState(()=>preferences=value);}),
  );
}

class StudyHome extends StatefulWidget {
  final AppStorage store;
  final UserPreferences preferences;
  final bool syncOnStart;
  final ValueChanged<UserPreferences> onPreferencesChanged;
  const StudyHome({required this.store,required this.preferences,required this.syncOnStart,required this.onPreferencesChanged,super.key});
  @override
  State<StudyHome> createState()=>_StudyHomeState();
}

class _StudyHomeState extends State<StudyHome> {
  Catalog? catalog;
  Map<int,String> local={};
  Set<int> favorites={};
  int usedBytes=0,tab=0;
  bool ready=false,busy=false,offline=false,bootError=false,bulk=false,favoritesOnly=false;
  String section='all',query='';
  String? level,track,subject;
  int? year,downloading;
  double progress=0;
  final searchController=TextEditingController();
  Timer? searchTimer;
  DateTime lastProgress=DateTime.fromMillisecondsSinceEpoch(0);
  bool get french=>widget.preferences.french;
  bool get transferring=>downloading!=null||bulk;
  String t(String ar,String fr)=>french?fr:ar;
  @override
  void initState(){super.initState();unawaited(boot());}
  @override
  void dispose(){searchTimer?.cancel();searchController.dispose();super.dispose();}

  Future<void> boot() async {
    setState((){ready=false;bootError=false;});
    try {
      await widget.store.open();
      final preferences=await widget.store.preferences();
      final cached=await widget.store.cachedCatalog();
      final files=await widget.store.downloaded();
      final bookmarks=await widget.store.favorites();
      final bytes=await widget.store.storageBytes();
      if(!mounted)return;
      widget.onPreferencesChanged(preferences);
      setState((){catalog=cached;local=files;favorites=bookmarks;usedBytes=bytes;ready=true;});
      if(widget.syncOnStart)await refresh();
    } catch (_) {
      if(mounted)setState((){ready=true;bootError=true;});
    }
  }

  Future<void> refresh() async {
    if(busy)return;
    if(bootError){await boot();return;}
    setState(()=>busy=true);
    try {
      final updated=await widget.store.sync();
      if(mounted)setState((){catalog=updated;offline=false;});
    } catch (_) {
      if(mounted)setState(()=>offline=true);
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> updatePreferences(UserPreferences value) async {
    widget.onPreferencesChanged(value);
    try {await widget.store.savePreferences(value);}
    catch (_) {if(mounted)notify(t('تعذر حفظ الإعدادات. أعد المحاولة.','Impossible d’enregistrer les réglages. Réessayez.'));}
  }

  Future<void> toggleFavorite(Resource resource) async {
    final previous=favorites.contains(resource.id);
    setState((){if(previous){favorites.remove(resource.id);}else{favorites.add(resource.id);}});
    try {await widget.store.setFavorite(resource.id,!previous);}
    catch (_) {
      if(mounted){setState((){if(previous){favorites.add(resource.id);}else{favorites.remove(resource.id);}});notify(t('تعذر حفظ المفضلة','Impossible de modifier les favoris'));}
    }
  }

  Future<void> reloadLocal() async {
    final files=await widget.store.downloaded();
    final bytes=await widget.store.storageBytes();
    if(mounted)setState((){local=files;usedBytes=bytes;});
  }

  Future<String?> download(Resource resource) async {
    if(downloading!=null)return null;
    setState((){downloading=resource.id;progress=0;});
    try {
      final path=await widget.store.download(resource,onProgress:(received,total){
        final now=DateTime.now();
        if(mounted&&(received==total||now.difference(lastProgress).inMilliseconds>120)) {
          lastProgress=now;setState(()=>progress=total>0?received/total:0);
        }
      });
      if(mounted)setState(()=>local[resource.id]=path);
      await reloadLocal();
      return path;
    } catch (_) {
      if(mounted&&!bulk)notify(t('تعذر التنزيل. أعد المحاولة لاستكماله.','Téléchargement interrompu. Réessayez pour reprendre.'));
      return null;
    } finally {if(mounted)setState(()=>downloading=null);}
  }

  String resourceUrl(Resource resource) => '$apiBase/v1/files/${resource.id}';

  Future<void> openResource(Resource resource) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_) => FileDetailsScreen(
      resource:resource,apiUrl:resourceUrl(resource),french:french,
      localPath:local[resource.id],initiallyFavorite:favorites.contains(resource.id),
      onFavorite:()=>toggleFavorite(resource),onDownload:()=>download(resource),
    )));
  }

  Future<void> previewResource(Resource resource) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_) => FileReaderScreen(
      title:resource.display(french),apiUrl:resourceUrl(resource),
      localPath:local[resource.id],french:french,onDownload:()=>download(resource),
    )));
  }

  Future<void> downloadMany(List<Resource> resources) async {
    if(transferring)return;
    final missing=resources.where((resource)=>!local.containsKey(resource.id)).toList();
    if(missing.isEmpty){notify(t('كل هذه الملفات محفوظة بالفعل','Tous ces documents sont déjà enregistrés'));return;}
    final bytes=missing.fold<int>(0,(sum,resource)=>sum+resource.size);
    final approved=await confirm(t('جهّز دراستك دون إنترنت','Préparez vos cours hors ligne'),
      t('سيُحفظ ${missing.length} ملفًا (${humanSize(bytes)}) على هاتفك.','${missing.length} documents (${humanSize(bytes)}) seront enregistrés sur cet appareil.'),
      t('تنزيل الملفات','Télécharger'));
    if(!approved||!mounted)return;
    setState(()=>bulk=true);
    var succeeded=0;
    try {
      for(final resource in missing){
        if(!mounted)break;
        if(await download(resource)!=null)succeeded++;
      }
    } finally {if(mounted)setState(()=>bulk=false);}
    if(mounted)notify(t('تم حفظ $succeeded من ${missing.length} ملفًا','Enregistrés : $succeeded sur ${missing.length}'));
  }

  Future<void> removeResource(Resource resource) async {
    if(transferring)return;
    final approved=await confirm(t('حذف التنزيل؟','Supprimer le téléchargement ?'),
      t('يمكنك تنزيل الملف مجددًا لاحقًا. ستبقى المفضلة محفوظة.','Vous pourrez le télécharger à nouveau. Vos favoris seront conservés.'),t('حذف','Supprimer'));
    if(!approved||!mounted)return;
    try {await widget.store.remove(resource.id);await reloadLocal();}
    catch (_) {if(mounted)notify(t('تعذر حذف الملف','Impossible de supprimer ce fichier'));}
  }

  Future<void> clearDownloads() async {
    if(transferring)return;
    final approved=await confirm(t('إخلاء مساحة التنزيلات؟','Libérer l’espace des téléchargements ?'),
      t('ستُحذف الملفات المحفوظة وأجزاء التنزيل. يبقى الفهرس والمفضلة.','Les documents téléchargés et les fichiers partiels seront supprimés. Le catalogue et les favoris sont conservés.'),t('حذف التنزيلات','Supprimer les téléchargements'));
    if(!approved||!mounted)return;
    try {await widget.store.clearDownloads();await reloadLocal();}
    catch (_) {if(mounted)notify(t('تعذر إخلاء المساحة','Impossible de libérer cet espace'));}
  }

  Future<bool> confirm(String title,String message,String action) async => await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
    title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(t('إلغاء','Annuler'))),
      FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(action)),
    ]))??false;

  void notify(String message){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),behavior:SnackBarBehavior.floating));}

  void browse({String category='all',String? selectedLevel,String? selectedTrack,String? selectedSubject}) {
    searchTimer?.cancel();searchController.clear();
    setState((){tab=1;section=category;level=selectedLevel;track=selectedTrack;subject=selectedSubject;year=null;query='';});
  }

  void searchChanged(String value) {
    searchTimer?.cancel();
    searchTimer=Timer(const Duration(milliseconds:220),(){if(mounted)setState(()=>query=value);});
  }

  Widget searchField() => TextField(key:const ValueKey('search-field'),controller:searchController,onChanged:searchChanged,
    textInputAction:TextInputAction.search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:t('ابحث بالعربية أو الفرنسية','Rechercher en arabe ou en français'),
    suffixIcon:IconButton(tooltip:t('مسح البحث','Effacer la recherche'),onPressed:(){searchTimer?.cancel();searchController.clear();setState(()=>query='');},icon:const Icon(Icons.close_rounded))));

  ResourceTile resourceTile(Resource resource) {
    final subjects={for(final node in catalog?.subjects??<Node>[])node.id:node};
    return ResourceTile(resource:resource,subject:subjects[resource.subjectId]?.display(french)??'',french:french,
      saved:local.containsKey(resource.id),favorite:favorites.contains(resource.id),progress:downloading==resource.id?progress:null,
      onOpen:()=>openResource(resource),onPreview:()=>previewResource(resource),
      onFavorite:()=>toggleFavorite(resource),
      onDownload:transferring?null:()=>download(resource),onDelete:transferring?null:()=>removeResource(resource));
  }

  @override
  Widget build(BuildContext context) {
    final pages=[t('مساحتك للدراسة','Votre espace pour apprendre'),t('المكتبة الدراسية','Bibliothèque scolaire'),t('دراستك، أينما كنت','Vos cours, où que vous soyez'),t('دراستك، بطريقتك','Vos études, à votre façon')];
    return Scaffold(
      appBar:AppBar(leadingWidth:72,leading:const Padding(padding:EdgeInsetsDirectional.fromSTEB(20,16,8,16),child:BrandMark()),
        title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Mauri student',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
          Text(pages[tab],style:Theme.of(context).textTheme.labelSmall,maxLines:1,overflow:TextOverflow.ellipsis),
        ]),actions:[
          TextButton(key:const ValueKey('language-toggle'),onPressed:()=>updatePreferences(widget.preferences.copyWith(french:!french)),child:Text(french?'عربي':'FR')),
          IconButton(key:const ValueKey('settings-button'),tooltip:t('الإعدادات','Réglages'),onPressed:()=>setState(()=>tab=3),icon:const Icon(Icons.tune_rounded)),
        ]),
      body:SafeArea(bottom:false,child:Column(children:[
        if(busy)const LinearProgressIndicator(minHeight:2),
        if(offline||bootError)Container(width:double.infinity,color:Theme.of(context).colorScheme.secondaryContainer,
          padding:const EdgeInsetsDirectional.fromSTEB(20,8,12,8),child:Row(children:[
            const Icon(Icons.wifi_off_rounded,size:18),const SizedBox(width:10),
            Expanded(child:Text(t(catalog==null?'اتصل بالإنترنت لجلب المكتبة أول مرة':'تتصفح الفهرس المحفوظ دون اتصال',catalog==null?'Connectez-vous pour charger le catalogue':'Vous consultez le catalogue hors ligne'),style:Theme.of(context).textTheme.bodySmall)),
            TextButton(onPressed:busy?null:refresh,child:Text(t('تحديث','Actualiser'))),
          ])),
        if(downloading!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:6),child:Row(children:[
          const Icon(Icons.downloading_rounded,size:20),const SizedBox(width:10),
          Expanded(child:Text(t('جارٍ تجهيز ملفك دون إنترنت…','Votre document sera bientôt disponible hors ligne…'),style:Theme.of(context).textTheme.labelSmall)),
          Text('${(progress.clamp(0,1)*100).round()}%'),
        ])),
        Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:960),child:!ready
          ?const Center(child:CircularProgressIndicator())
          :bootError?EmptyPanel(icon:Icons.folder_off_outlined,title:t('تعذر فتح المكتبة','Bibliothèque indisponible'),message:t('أعد المحاولة لفتح مساحة الدراسة.','Réessayez pour ouvrir votre espace d’étude.'),actionLabel:t('إعادة المحاولة','Réessayer'),onAction:boot)
          :tab==0?homePage():tab==1?libraryPage():tab==2?myLibraryPage():settingsPage()))),
      ])),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(value)=>setState(()=>tab=value),destinations:[
        NavigationDestination(key:const ValueKey('nav-home'),icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home_rounded),label:t('الرئيسية','Accueil')),
        NavigationDestination(key:const ValueKey('nav-library'),icon:const Icon(Icons.grid_view_outlined),selectedIcon:const Icon(Icons.grid_view_rounded),label:t('المكتبة','Explorer')),
        NavigationDestination(key:const ValueKey('nav-saved'),icon:const Icon(Icons.collections_bookmark_outlined),selectedIcon:const Icon(Icons.collections_bookmark_rounded),label:t('مكتبتي','Mes cours')),
        NavigationDestination(key:const ValueKey('nav-settings'),icon:const Icon(Icons.settings_outlined),selectedIcon:const Icon(Icons.settings_rounded),label:t('الإعدادات','Réglages')),
      ]),
    );
  }

  Widget homePage() {
    final data=catalog;
    final recent=data==null?<Resource>[]:filterResources(data).take(5).toList();
    return RefreshIndicator(onRefresh:refresh,child:ListView(key:const PageStorageKey('home'),padding:const EdgeInsets.fromLTRB(20,20,20,24),physics:const AlwaysScrollableScrollPhysics(),children:[
      Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:studyGreen,borderRadius:BorderRadius.circular(28)),child:Stack(children:[
        const PositionedDirectional(end:-14,top:10,child:ExcludeSemantics(child:Icon(Icons.auto_stories_rounded,size:160,color:Color(0x2439C994)))),
        Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.12),borderRadius:BorderRadius.circular(20)),
            child:Text(t('معك في كل خطوة','À vos côtés, chaque jour'),style:const TextStyle(color:Colors.white,fontSize:12))),
          const SizedBox(height:16),Text(t('مستقبلك يبدأ\nبدرس اليوم','Votre réussite,\nun cours à la fois.'),style:Theme.of(context).textTheme.headlineMedium?.copyWith(color:Colors.white)),
          const SizedBox(height:12),Text(t('دروسك وتمارينك في مكان واحد. احفظ ما تحتاجه وادرس أينما كنت.','Cours, exercices et examens réunis. Enregistrez vos documents pour étudier partout.'),style:const TextStyle(color:Color(0xFFD4E5DC),height:1.7)),
          const SizedBox(height:20),FilledButton.icon(onPressed:()=>browse(),style:FilledButton.styleFrom(backgroundColor:studyGold,foregroundColor:const Color(0xFF233C2D)),
            icon:const Icon(Icons.explore_outlined),label:Text(t('استكشف المكتبة','Explorer la bibliothèque'))),
        ])),
      ])),
      const SizedBox(height:16),Row(children:[
        Expanded(child:StatPill(icon:Icons.menu_book_outlined,label:t('ملف في مكتبتك الدراسية','documents à découvrir'),value:'${data?.resources.length??0}')),
        const SizedBox(width:12),Expanded(child:StatPill(icon:Icons.offline_pin_outlined,label:t('ملف محفوظ دون إنترنت','documents hors ligne'),value:'${local.length}')),
      ]),
      const SizedBox(height:18),InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>browse(),child:InputDecorator(decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded)),
        child:Text(t('ماذا تريد أن تتعلم اليوم؟','Que voulez-vous apprendre aujourd’hui ?'),style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)))),
      if(data!=null&&data.resources.isNotEmpty)...[
        SectionHeading(title:t('ابدأ من مستواك','Choisissez votre niveau')),
        Wrap(spacing:10,runSpacing:10,children:data.levels.where((node)=>data.tracks.any((track)=>track.levelId==node.id&&data.subjects.any((subject)=>subject.trackId==track.id&&data.resources.any((file)=>file.subjectId==subject.id)))).map((node)=>ActionChip(avatar:const Icon(Icons.school_outlined,size:18),label:Text(node.display(french)),onPressed:()=>browse(selectedLevel:node.id))).toList()),
      ],
      SectionHeading(title:t('كل ما تحتاجه للدراسة','Tout pour vos études')),
      LayoutBuilder(builder:(context,constraints){
        final width=(constraints.maxWidth-12)/2;
        final choices=[('lesson',Icons.auto_stories_outlined,t('الدروس','Cours')),('exam',Icons.assignment_outlined,t('الامتحانات','Examens')),('practice',Icons.edit_note_rounded,t('التمارين والملخصات','Exercices et résumés')),('book',Icons.local_library_outlined,t('الكتب والمراجع','Livres et références'))];
        return Wrap(spacing:12,runSpacing:12,children:choices.where((choice)=>data!=null&&data.resources.any((file)=>choice.$1=='practice'?const {'exercise','summary'}.contains(file.kind):file.kind==choice.$1)).map((choice){
          return SizedBox(width:width,child:Card(child:InkWell(
            borderRadius:BorderRadius.circular(22),onTap:()=>browse(category:choice.$1),
            child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Icon(choice.$2,color:Theme.of(context).colorScheme.primary,size:28),
              const SizedBox(height:12),Text(choice.$3,style:Theme.of(context).textTheme.titleMedium),
            ])),
          )));
        }).toList());
      }),
      if(data!=null&&data.resources.isNotEmpty)...[
        SectionHeading(title:t('شعبتك، طريقك إلى النجاح','Votre série, votre parcours')),
        Wrap(spacing:8,runSpacing:8,children:data.tracks.where((node)=>data.subjects.any((sub)=>sub.trackId==node.id&&data.resources.any((file)=>file.subjectId==sub.id))).map((node)=>ActionChip(label:Text(node.display(french)),onPressed:()=>browse(selectedLevel:node.levelId,selectedTrack:node.id))).toList()),
      ],
      SectionHeading(title:t('أحدث الإضافات','Derniers ajouts'),actionLabel:t('عرض الكل','Tout voir'),onAction:()=>browse()),
      if(recent.isEmpty)EmptyPanel(icon:Icons.menu_book_outlined,title:t('مكتبتك تنتظرك','Votre bibliothèque vous attend'),message:t('حدّث الفهرس لعرض الملفات المتاحة.','Actualisez le catalogue pour découvrir les documents disponibles.'),actionLabel:t('تحديث المكتبة','Actualiser'),onAction:busy?null:refresh)
      else ...recent.map(resourceTile),
    ]));
  }

  List<Resource> currentResources({Set<int>? allowed}) => catalog==null?[]:filterResources(catalog!,levelId:level,trackId:track,subjectId:subject,section:section,year:year,query:query,allowedIds:allowed);

  // Year → track → subject are shown in the library, not hidden in filters.
  // Only paths with published content appear until the migration completes.
  Widget hierarchyPicker(Catalog data) {
    final publishedSubjects=data.resources.map((resource)=>resource.subjectId).toSet();
    final availableSubjects=data.subjects.where((node)=>publishedSubjects.contains(node.id)).toList();
    final availableTracks=availableSubjects.map((node)=>node.trackId).whereType<String>().toSet();
    final tracks=data.tracks.where((node)=>node.levelId==level&&availableTracks.contains(node.id)).toList();
    final subjects=availableSubjects.where((node)=>node.trackId==track).toList();
    final levels=data.levels.where((node)=>data.tracks.any((branch)=>branch.levelId==node.id&&availableTracks.contains(branch.id))).toList();
    Widget chips(List<Node> nodes,String? selected,void Function(String) onTap,String prefix) =>
      Wrap(spacing:8,runSpacing:6,children:[for(final node in nodes)
        ChoiceChip(key:ValueKey('$prefix-${node.id}'),label:Text(node.display(french)),
          selected:selected==node.id,showCheckmark:false,onSelected:(_)=>onTap(node.id))]);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(t('1. اختر السنة الدراسية','1. Choisissez votre niveau'),style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:9),
      chips(levels,level,(id)=>setState((){level=level==id?null:id;track=null;subject=null;year=null;}),'level'),
      if(level!=null&&tracks.isNotEmpty)...[
        const SizedBox(height:13),Text(t('2. اختر الشعبة','2. Choisissez votre série'),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:9),chips(tracks,track,(id)=>setState((){track=track==id?null:id;subject=null;year=null;}),'track'),
      ],
      if(track!=null&&subjects.isNotEmpty)...[
        const SizedBox(height:13),Text(t('3. اختر المادة','3. Choisissez la matière'),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:9),chips(subjects,subject,(id)=>setState(()=>subject=subject==id?null:id),'subject'),
      ],
      const SizedBox(height:15),
    ]);
  }

  Widget libraryPage() {
    final resources=currentResources();
    final categories=[('all',t('الكل','Tout')),('lesson',t('دروس','Cours')),('exam',t('امتحانات','Examens')),('practice',t('تمارين وملخصات','Exercices et résumés')),('book',t('مراجع','Livres'))];
    final visibleKinds=filterResources(catalog!,levelId:level,trackId:track,subjectId:subject,query:query);
    final visibleCategories=categories.where((cat)=>cat.$1=='all'||visibleKinds.any((item)=>cat.$1=='practice'?const {'exercise','summary'}.contains(item.kind):item.kind==cat.$1)).toList();
    return RefreshIndicator(onRefresh:refresh,child:CustomScrollView(key:const PageStorageKey('library'),physics:const AlwaysScrollableScrollPhysics(),slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(20,20,20,0),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(catalog!=null&&catalog!.resources.isNotEmpty)hierarchyPicker(catalog!),
        searchField(),const SizedBox(height:14),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:visibleCategories.map((category)=>Padding(padding:const EdgeInsetsDirectional.only(end:8),child:ChoiceChip(
          label:Text(category.$2),selected:section==category.$1,onSelected:(_)=>setState(()=>section=category.$1)))).toList())),
        const SizedBox(height:8),Row(children:[
          Expanded(child:Text(t('${resources.length} ملفًا متاحًا','${resources.length} documents'),style:Theme.of(context).textTheme.labelLarge)),
          OutlinedButton.icon(key:const ValueKey('filter-button'),onPressed:catalog==null?null:showFilters,icon:const Icon(Icons.tune_rounded,size:18),label:Text(t('تصفية','Filtres'))),
        ]),
        if(level!=null||track!=null||subject!=null||year!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Wrap(spacing:6,runSpacing:6,children:[
          if(level!=null)InputChip(label:Text(nodeLabel(catalog!.levels,level!)),onDeleted:()=>setState((){level=null;track=null;subject=null;})),
          if(track!=null)InputChip(label:Text(nodeLabel(catalog!.tracks,track!)),onDeleted:()=>setState((){track=null;subject=null;})),
          if(subject!=null)InputChip(label:Text(nodeLabel(catalog!.subjects,subject!)),onDeleted:()=>setState(()=>subject=null)),
          if(year!=null)InputChip(label:Text('$year'),onDeleted:()=>setState(()=>year=null)),
        ])),
        if(resources.isNotEmpty&&(track!=null||subject!=null))Padding(padding:const EdgeInsets.only(bottom:14),child:OutlinedButton.icon(
          onPressed:transferring?null:()=>downloadMany(resources),icon:const Icon(Icons.download_for_offline_outlined),label:Text(t('حفظ هذه المجموعة دون إنترنت','Enregistrer cette sélection hors ligne')))),
        const SizedBox(height:8),
      ]))),
      if(resources.isEmpty)SliverToBoxAdapter(child:EmptyPanel(icon:Icons.search_off_rounded,title:t('لا توجد ملفات هنا بعد','Aucun document ici pour le moment'),message:t('جرّب قسمًا آخر أو خفف الفلاتر والبحث.','Essayez une autre catégorie ou modifiez vos filtres.'),
        actionLabel:t('عرض كل الملفات','Afficher tous les documents'),onAction:()=>browse()))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,24),sliver:SliverList.builder(itemCount:resources.length,itemBuilder:(_,index)=>resourceTile(resources[index]))),
    ]));
  }

  String nodeLabel(List<Node> nodes,String id) => nodes.where((node)=>node.id==id).firstOrNull?.display(french)??id;

  Future<void> showFilters() async {
    final data=catalog;
    if(data==null)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
      builder:(_)=>BrowseFilters(catalog:data,french:french,level:level,track:track,subject:subject,year:year,
        onApply:(newLevel,newTrack,newSubject,newYear)=>setState((){level=newLevel;track=newTrack;subject=newSubject;year=newYear;})));
  }

  Widget myLibraryPage() {
    final allowed=favoritesOnly?favorites:local.keys.toSet();
    final resources=catalog==null?<Resource>[]:filterResources(catalog!,query:query,allowedIds:allowed);
    return CustomScrollView(key:const PageStorageKey('saved'),slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(20,20,20,16),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[
          Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.offline_pin_rounded,size:30)),
          const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('دراستك ترافقك','Vos cours vous accompagnent'),style:Theme.of(context).textTheme.titleMedium),
            Text(t('${local.length} ملفًا محفوظًا · ${usedBytes==0?'0 KB':humanSize(usedBytes)}','${local.length} documents enregistrés · ${usedBytes==0?'0 KB':humanSize(usedBytes)}'),style:Theme.of(context).textTheme.bodySmall),
          ])),
        ]))),
        const SizedBox(height:18),SegmentedButton<bool>(segments:[ButtonSegment(value:false,icon:const Icon(Icons.download_done_rounded),label:Text(t('التنزيلات','Téléchargés'))),ButtonSegment(value:true,icon:const Icon(Icons.bookmark_outline_rounded),label:Text(t('المفضلة','Favoris')))],
          selected:{favoritesOnly},showSelectedIcon:false,onSelectionChanged:(selection)=>setState(()=>favoritesOnly=selection.first)),
        const SizedBox(height:16),searchField(),
      ]))),
      if(resources.isEmpty)SliverToBoxAdapter(child:EmptyPanel(icon:favoritesOnly?Icons.bookmark_border_rounded:Icons.cloud_download_outlined,
        title:t(favoritesOnly?'اجمع ملفاتك المفضلة':'ابدأ مكتبتك دون إنترنت',favoritesOnly?'Gardez vos documents favoris':'Créez votre bibliothèque hors ligne'),
        message:t(favoritesOnly?'اضغط علامة الحفظ بجانب أي ملف لتجده هنا.':'نزّل درسًا من المكتبة ليصبح متاحًا حتى دون اتصال. ورغم حفظه في المفضلة، يحتاج الملف إلى تنزيل مستقل.',favoritesOnly?'Touchez le signet d’un document pour le retrouver ici.':'Téléchargez un cours pour le lire sans connexion. Un favori doit être téléchargé séparément.'),
        actionLabel:t('استكشاف المكتبة','Explorer la bibliothèque'),onAction:()=>browse()))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,24),sliver:SliverList.builder(itemCount:resources.length,itemBuilder:(_,index)=>resourceTile(resources[index]))),
    ]);
  }

  Widget settingsPage() {
    final scheme=Theme.of(context).colorScheme;
    return ListView(key:const PageStorageKey('settings'),padding:const EdgeInsets.fromLTRB(20,20,20,24),children:[
      Text(t('اجعل مساحتك مناسبة لك','Un espace qui vous ressemble'),style:Theme.of(context).textTheme.titleLarge),
      SectionHeading(title:t('لغة التطبيق','Langue de l’application')),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('العربية')),ButtonSegment(value:true,label:Text('Français'))],selected:{french},
        onSelectionChanged:(selection)=>updatePreferences(widget.preferences.copyWith(french:selection.first))),
      SectionHeading(title:t('المظهر','Apparence')),
      Card(child:Column(children:[
        for(final option in [('system',Icons.brightness_auto_outlined,t('حسب الهاتف','Selon l’appareil')),('light',Icons.light_mode_outlined,t('فاتح','Clair')),('dark',Icons.dark_mode_outlined,t('داكن','Sombre'))])
          ListTile(key:ValueKey('theme-${option.$1}'),leading:Icon(option.$2),title:Text(option.$3),trailing:widget.preferences.theme==option.$1?Icon(Icons.check_circle_rounded,color:scheme.primary):null,
            onTap:()=>updatePreferences(widget.preferences.copyWith(theme:option.$1))),
      ])),
      SectionHeading(title:t('المساحة والتنزيلات','Stockage et téléchargements')),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(usedBytes==0?'0 KB':humanSize(usedBytes),style:Theme.of(context).textTheme.headlineMedium),
        Text(t('مساحة ملفاتك المحفوظة وأجزاء التنزيل','Espace utilisé par vos documents et téléchargements partiels'),style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:16),OutlinedButton.icon(onPressed:usedBytes==0||transferring?null:clearDownloads,icon:const Icon(Icons.delete_outline_rounded),label:Text(t('حذف كل التنزيلات','Supprimer les téléchargements'))),
        Text(t('يظل الفهرس والمفضلة محفوظين.','Le catalogue et vos favoris restent enregistrés.'),style:Theme.of(context).textTheme.labelSmall,textAlign:TextAlign.center),
      ]))),
      const SizedBox(height:24),const Center(child:BrandMark(size:54)),const SizedBox(height:12),
      Text('Mauri student',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
      Text(t('خطوة صغيرة كل يوم، ومستقبل أكبر.','Un petit pas chaque jour, un avenir plus grand.'),textAlign:TextAlign.center),
      const SizedBox(height:6),Text(t('نسخة تجريبية 0.2.0','Version d’essai 0.2.0'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

