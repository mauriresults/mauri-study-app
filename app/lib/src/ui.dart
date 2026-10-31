import 'package:flutter/material.dart';
import 'models.dart';

const studyGreen = Color(0xFF176349);
const studyGold = Color(0xFFE6BC61);

ThemeData studyTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor:studyGreen,brightness:brightness)
      .copyWith(tertiary:brightness==Brightness.light?const Color(0xFF88621B):studyGold);
  final base = ThemeData(useMaterial3:true,colorScheme:scheme);
  return base.copyWith(
    scaffoldBackgroundColor:brightness==Brightness.light?const Color(0xFFF5F7F3):const Color(0xFF111C17),
    appBarTheme:AppBarTheme(backgroundColor:scheme.surface,elevation:0,scrolledUnderElevation:0,toolbarHeight:76),
    navigationBarTheme:NavigationBarThemeData(backgroundColor:scheme.surface,height:78,indicatorColor:scheme.primaryContainer),
    cardTheme:CardThemeData(elevation:0,margin:EdgeInsets.zero,color:scheme.surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:BorderSide(color:scheme.outlineVariant.withValues(alpha:0.55)))),
    inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:scheme.surfaceContainerLow,
      contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:15),
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
      padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
    textTheme:base.textTheme.copyWith(
      headlineMedium:base.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800,height:1.35),
      titleLarge:base.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700),
      titleMedium:base.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700,height:1.45),
      bodyMedium:base.textTheme.bodyMedium?.copyWith(height:1.6)),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key,this.size=44});
  @override
  Widget build(BuildContext context) => Container(width:size,height:size,
    decoration:BoxDecoration(color:studyGreen,borderRadius:BorderRadius.circular(size*0.3)),
    child:Icon(Icons.auto_stories_rounded,color:studyGold,size:size*0.56));
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeading({required this.title,this.actionLabel,this.onAction,super.key});
  @override
  Widget build(BuildContext context) => Padding(padding:const EdgeInsets.only(top:22,bottom:12),child:Row(children:[
    Expanded(child:Text(title,style:Theme.of(context).textTheme.titleLarge)),
    if(onAction!=null)TextButton(onPressed:onAction,child:Text(actionLabel??'')),
  ]));
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title,message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyPanel({required this.icon,required this.title,required this.message,this.actionLabel,this.onAction,super.key});
  @override
  Widget build(BuildContext context) => Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(28)),
      child:Icon(icon,size:38,color:Theme.of(context).colorScheme.onPrimaryContainer)),
    const SizedBox(height:20),
    Text(title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:8),Text(message,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium),
    if(onAction!=null)Padding(padding:const EdgeInsets.only(top:18),child:FilledButton(onPressed:onAction,child:Text(actionLabel??''))),
  ])));
}

class StatPill extends StatelessWidget {
  final IconData icon;
  final String label,value;
  const StatPill({required this.icon,required this.label,required this.value,super.key});
  @override
  Widget build(BuildContext context) => Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
    Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:Theme.of(context).textTheme.titleLarge),
      Text(label,style:Theme.of(context).textTheme.labelMedium,maxLines:2),
    ])),
  ])));
}

class ResourceTile extends StatelessWidget {
  final Resource resource;
  final String subject;
  final bool french,saved,favorite;
  final double? progress;
  final VoidCallback onOpen,onPreview,onFavorite;
  final VoidCallback? onDownload,onDelete;
  const ResourceTile({required this.resource,required this.subject,required this.french,
    required this.saved,required this.favorite,required this.onOpen,required this.onPreview,required this.onFavorite,
    this.progress,this.onDownload,this.onDelete,super.key});
  String t(String ar,String fr)=>french?fr:ar;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = resource.kind=='exam'?Icons.assignment_outlined
        :resource.kind=='exercise'?Icons.edit_note_rounded
        :resource.kind=='book'?Icons.menu_book_rounded:Icons.description_outlined;
    return Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:InkWell(
      borderRadius:BorderRadius.circular(22),onTap:onOpen,
      child:Padding(padding:const EdgeInsetsDirectional.fromSTEB(14,14,6,14),child:Column(children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:44,height:52,decoration:BoxDecoration(color:scheme.primaryContainer,borderRadius:BorderRadius.circular(14)),
            child:Icon(icon,color:scheme.onPrimaryContainer)),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(resource.display(french),style:Theme.of(context).textTheme.titleMedium,maxLines:3,overflow:TextOverflow.ellipsis),
            const SizedBox(height:5),
            Text(subject.isEmpty?resource.typeLabel(french):subject,style:TextStyle(color:scheme.onSurfaceVariant),maxLines:2,overflow:TextOverflow.ellipsis),
            const SizedBox(height:9),
            Wrap(spacing:8,runSpacing:5,crossAxisAlignment:WrapCrossAlignment.center,children:[
              Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:scheme.surfaceContainerHigh,borderRadius:BorderRadius.circular(7)),
                child:Text('${resource.typeLabel(french)}${resource.examYear==null?'':' · ${resource.examYear}'}',style:Theme.of(context).textTheme.labelSmall)),
              Text(humanSize(resource.size),style:Theme.of(context).textTheme.labelSmall),
              if(saved)Icon(Icons.offline_pin_rounded,size:16,color:scheme.primary),
            ]),
          ])),
          Column(mainAxisSize:MainAxisSize.min,children:[
            IconButton(key:ValueKey('favorite-${resource.id}'),tooltip:t(favorite?'إزالة من المفضلة':'إضافة للمفضلة',favorite?'Retirer des favoris':'Ajouter aux favoris'),
              onPressed:onFavorite,icon:Icon(favorite?Icons.bookmark_rounded:Icons.bookmark_border_rounded,color:favorite?scheme.primary:scheme.onSurfaceVariant)),
            if(progress!=null)SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2,value:progress!>0?progress!.clamp(0,1).toDouble():null))
            else if(!saved&&onDownload!=null)IconButton(key:ValueKey('download-${resource.id}'),
              tooltip:t('تنزيل الملف','Télécharger le document'),onPressed:onDownload,
              icon:const Icon(Icons.download_for_offline_outlined))
            else PopupMenuButton<String>(tooltip:t('خيارات الملف','Options du document'),icon:const Icon(Icons.more_horiz_rounded),
              onSelected:(action){
                if(action=='open')onOpen();
                if(action=='download')onDownload?.call();
                if(action=='delete')onDelete?.call();
              },itemBuilder:(_)=>[
                PopupMenuItem(value:'open',child:Text(t('فتح الملف','Ouvrir'))),
                if(!saved&&onDownload!=null)PopupMenuItem(value:'download',child:Text(t('تنزيل دون إنترنت','Télécharger hors ligne'))),
                if(saved&&onDelete!=null)PopupMenuItem(value:'delete',child:Text(t('حذف النسخة المحفوظة','Supprimer la copie locale'))),
              ]),
          ]),
        ]),
        Padding(padding:const EdgeInsets.only(top:10),child:Wrap(alignment:WrapAlignment.spaceBetween,spacing:4,runSpacing:4,children:[
          TextButton.icon(key:ValueKey('preview-${resource.id}'),
            onPressed:onPreview,icon:const Icon(Icons.visibility_outlined,size:18),
            style:TextButton.styleFrom(visualDensity:VisualDensity.compact,padding:const EdgeInsets.symmetric(horizontal:8)),
            label:Text(t('مشاهدة الآن','Voir maintenant'))),
          TextButton.icon(key:ValueKey('save-${resource.id}'),
            onPressed:saved?null:onDownload,icon:Icon(saved?Icons.offline_pin_rounded:Icons.download_outlined,size:18),
            style:TextButton.styleFrom(visualDensity:VisualDensity.compact,padding:const EdgeInsets.symmetric(horizontal:8)),
            label:Text(saved?t('محفوظ','Enregistré'):t('تنزيل','Télécharger'))),
        ])),
        if(progress!=null)Padding(padding:const EdgeInsets.only(top:12),child:ClipRRect(borderRadius:BorderRadius.circular(4),
          child:LinearProgressIndicator(value:progress!.clamp(0,1).toDouble(),minHeight:3))),
      ])),
    )));
  }
}

class BrowseFilters extends StatefulWidget {
  final Catalog catalog;
  final bool french;
  final String? level,track,subject;
  final int? year;
  final void Function(String?,String?,String?,int?) onApply;
  const BrowseFilters({required this.catalog,required this.french,required this.onApply,this.level,this.track,this.subject,this.year,super.key});
  @override
  State<BrowseFilters> createState()=>_BrowseFiltersState();
}

class _BrowseFiltersState extends State<BrowseFilters> {
  String? level,track,subject;
  int? year;
  String t(String ar,String fr)=>widget.french?fr:ar;
  @override
  void initState(){super.initState();level=widget.level;track=widget.track;subject=widget.subject;year=widget.year;}
  Widget choose(String label,String? value,List<Node> nodes,ValueChanged<String?> change) => Padding(
    padding:const EdgeInsets.only(bottom:14),child:DropdownButtonFormField<String>(key:ValueKey('$label-$value'),initialValue:value,isExpanded:true,
    decoration:InputDecoration(labelText:label),items:[DropdownMenuItem(value:null,child:Text(t('الكل','Tous'))),
      ...nodes.map((node)=>DropdownMenuItem(value:node.id,child:Text(node.display(widget.french),overflow:TextOverflow.ellipsis)))],onChanged:change));
  @override
  Widget build(BuildContext context) {
    final tracks=widget.catalog.tracks.where((node)=>level==null||node.levelId==level).toList();
    final trackIds=tracks.map((node)=>node.id).toSet();
    final subjects=widget.catalog.subjects.where((node)=>track==null?trackIds.contains(node.trackId):node.trackId==track).toList();
    final years=widget.catalog.resources.map((resource)=>resource.examYear).whereType<int>().toSet().toList()..sort((a,b)=>b.compareTo(a));
    return SafeArea(child:SingleChildScrollView(padding:EdgeInsets.fromLTRB(24,12,24,24+MediaQuery.viewInsetsOf(context).bottom),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(t('اختر ما يناسب دراستك','Affinez votre recherche'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:24),
      choose(t('المستوى','Niveau'),level,widget.catalog.levels,(value)=>setState((){level=value;track=null;subject=null;})),
      choose(t('الشعبة','Série'),track,tracks,(value)=>setState((){track=value;subject=null;})),
      choose(t('المادة','Matière'),subject,subjects,(value)=>setState(()=>subject=value)),
      DropdownButtonFormField<int>(key:ValueKey('year-$year'),initialValue:year,isExpanded:true,decoration:InputDecoration(labelText:t('سنة الامتحان','Année de l’examen')),
        items:[DropdownMenuItem(value:null,child:Text(t('كل السنوات','Toutes les années'))),...years.map((value)=>DropdownMenuItem(value:value,child:Text('$value')))],
        onChanged:(value)=>setState(()=>year=value)),const SizedBox(height:24),
      FilledButton(onPressed:(){widget.onApply(level,track,subject,year);Navigator.pop(context);},child:Text(t('عرض الملفات','Afficher les documents'))),
      TextButton(onPressed:()=>setState((){level=null;track=null;subject=null;year=null;}),child:Text(t('إعادة ضبط الفلاتر','Réinitialiser les filtres'))),
    ])));
  }
}
