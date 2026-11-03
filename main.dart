import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AdhkarApp());

class AdhkarApp extends StatefulWidget {
  const AdhkarApp({super.key});
  @override
  State<AdhkarApp> createState() => _AdhkarAppState();
}

class _AdhkarAppState extends State<AdhkarApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'أذكار',
    theme: _theme(false), darkTheme: _theme(true), themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Directionality(textDirection: TextDirection.rtl,
      child: MainScreen(dark: dark, onTheme: () => setState(() => dark = !dark))),
  );
  ThemeData _theme(bool isDark) {
    const accent = Color(0xFF16866A);
    final base = isDark ? const Color(0xFF101B25) : const Color(0xFFE8EEF0);
    return ThemeData(useMaterial3: true, brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: base, colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: isDark ? Brightness.dark : Brightness.light),
      fontFamily: 'sans-serif', appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0));
  }
}

class MainScreen extends StatefulWidget {
  final bool dark; final VoidCallback onTheme;
  const MainScreen({super.key, required this.dark, required this.onTheme});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0, tasbeeh = 0, goal = 33;
  String period = 'morning', query = '';
  List<Map<String, dynamic>> items = [];
  final Map<String, int> counts = {};
  final Set<String> favorites = {};
  final TextEditingController search = TextEditingController();
  bool loadingPrayer = false;
  Map<String, String> prayerTimes = {};
  static const green = Color(0xFF16866A);

  @override
  void initState() { super.initState(); _load(); _loadPrayer(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('lib/data/adhkar.json');
    final data = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    if (!mounted) return;
    setState(() {
      items = data;
      tasbeeh = prefs.getInt('tasbeeh') ?? 0;
      goal = prefs.getInt('goal') ?? 33;
      for (final x in data) { counts[x['id']] = prefs.getInt('count_${x['id']}') ?? 0; }
      favorites.addAll(prefs.getStringList('favorites') ?? []);
    });
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('tasbeeh', tasbeeh); await p.setInt('goal', goal);
    for (final e in counts.entries) { await p.setInt('count_${e.key}', e.value); }
    await p.setStringList('favorites', favorites.toList());
  }
  Future<void> _loadPrayer() async {
    setState(() => loadingPrayer = true);
    try {
      // Sétif, Algeria. AlAdhan method 3 (Muslim World League); times are refreshed by date.
      final now = DateTime.now();
      final url = Uri.parse('https://api.aladhan.com/v1/timings/${now.day}-${now.month}-${now.year}?latitude=36.19&longitude=5.41&method=3');
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body)['data']['timings'] as Map<String, dynamic>;
      const keys = {'الفجر':'Fajr','الشروق':'Sunrise','الظهر':'Dhuhr','العصر':'Asr','المغرب':'Maghrib','العشاء':'Isha'};
      setState(() { prayerTimes = {for (final e in keys.entries) e.key: (data[e.value] as String).split(' ').first}; });
    } catch (_) { if (mounted) setState(() { prayerTimes = {}; }); }
    if (mounted) setState(() => loadingPrayer = false);
  }
  void _setTab(int value) { FocusScope.of(context).unfocus(); setState(() => tab = value); }
  List<Map<String, dynamic>> get visibleItems {
    Iterable<Map<String, dynamic>> list = items;
    if (tab == 1 && period == 'favorites') { list = list.where((x) => favorites.contains(x['id'])); }
    else if (tab == 1) { list = list.where((x) => x['type'] == period); }
    if (query.trim().isNotEmpty) list = list.where((x) => ('${x['text']} ${x['note']}').toString().contains(query.trim()));
    return list.toList();
  }
  @override
  Widget build(BuildContext context) {
    final titles = ['الرئيسية', 'الأذكار', 'المسبحة', 'المزيد'];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 8), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: green.withOpacity(.13), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: green)),
          const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('أذكار', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text('رفيق يومك إلى الطمأنينة', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor))])),
          IconButton(onPressed: widget.onTheme, icon: Icon(widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
        ])),
        Expanded(child: IndexedStack(index: tab, children: [_home(), _adhkar(), _tasbeehPage(), _more()])),
      ])),
      bottomNavigationBar: NavigationBar(height: 70, selectedIndex: tab, onDestinationSelected: _setTab,
        destinations: const [NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'), NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'الأذكار'), NavigationDestination(icon: Icon(Icons.radio_button_checked), label: 'المسبحة'), NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'المزيد')]),
    );
  }
  Widget _home() => ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 22), children: [
    Container(padding: const EdgeInsets.all(22), decoration: _glass(gradient: true), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_greeting(), style: const TextStyle(fontSize: 14, color: green, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
      const Text('ابدأ يومك بذكر الله', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      Text('﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾', style: TextStyle(fontSize: 17, height: 1.8, color: Theme.of(context).colorScheme.onSurface.withOpacity(.8))),
      const SizedBox(height: 18), Wrap(spacing: 8, children: [FilledButton.icon(onPressed: () {setState(() {period='morning';}); _setTab(1);}, icon: const Icon(Icons.wb_sunny_outlined), label: const Text('أذكار الصباح')), OutlinedButton.icon(onPressed: () {setState(() {period='evening';}); _setTab(1);}, icon: const Icon(Icons.nightlight_outlined), label: const Text('أذكار المساء'))])
    ])), const SizedBox(height: 14),
    Row(children: [Expanded(child: _quickCard('المسبحة', '$tasbeeh تسبيحة', Icons.radio_button_checked, () => _setTab(2))), const SizedBox(width: 12), Expanded(child: _quickCard('المفضلة', '${favorites.length} ذكر', Icons.favorite_outline, () {setState(() {tab=1;period='favorites';});}))]),
    const SizedBox(height: 18), _sectionTitle('مواقيت الصلاة في سطيف', Icons.access_time_rounded), const SizedBox(height: 10), _prayerCard(),
  ]);
  String _greeting() { final h=DateTime.now().hour; return h<12?'السلام عليكم، صباح الخير':h<18?'السلام عليكم، طاب يومك':'السلام عليكم، مساء الخير'; }
  Widget _quickCard(String title, String subtitle, IconData icon, VoidCallback tap) => InkWell(onTap: tap, borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(16), decoration: _glass(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: green, size: 25), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))])));
  Widget _adhkar() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: Column(children: [
      SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value:'morning',label:Text('الصباح'),icon:Icon(Icons.wb_sunny_outlined)),ButtonSegment(value:'evening',label:Text('المساء'),icon:Icon(Icons.nightlight_outlined)),ButtonSegment(value:'favorites',label:Text('المفضلة'),icon:Icon(Icons.favorite_outline))], selected: {period}, onSelectionChanged: (v)=>setState(()=>period=v.first)),
      const SizedBox(height: 10), TextField(controller: search, onChanged: (v)=>setState(()=>query=v), decoration: InputDecoration(hintText:'ابحث في الأذكار...', prefixIcon: const Icon(Icons.search), suffixIcon: query.isEmpty?null:IconButton(onPressed:(){search.clear();setState(()=>query='');},icon:const Icon(Icons.close)), filled:true, border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),
    ])),
    Expanded(child: items.isEmpty ? const Center(child:CircularProgressIndicator()) : visibleItems.isEmpty ? Center(child:Text(period=='favorites'?'لا توجد أذكار مفضلة بعد':'لا توجد نتائج')) : ListView.builder(padding: const EdgeInsets.fromLTRB(16,0,16,18), itemCount: visibleItems.length, itemBuilder: (context,index)=>_dhikrCard(visibleItems[index],index))),
  ]);
  Widget _dhikrCard(Map<String,dynamic> item,int index) {
    final id=item['id'] as String, target=item['count'] as int, current=counts[id]??0, done=current>=target, fav=favorites.contains(id);
    return Container(margin: const EdgeInsets.only(bottom:12), padding: const EdgeInsets.all(17), decoration: _glass(), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Text('${index+1}'.padLeft(2,'0'),style:const TextStyle(color:green,fontWeight:FontWeight.bold)), const Spacer(), IconButton(visualDensity:VisualDensity.compact,onPressed:(){setState(()=>fav?favorites.remove(id):favorites.add(id));_save();},icon:Icon(fav?Icons.favorite:Icons.favorite_border,color:fav?Colors.redAccent:null))]),
      SelectableText(item['text'], textAlign:TextAlign.center, style:const TextStyle(fontSize:20,height:2.0,fontWeight:FontWeight.w500)),
      if ((item['note'] as String).isNotEmpty) ...[const SizedBox(height:10),Text(item['note'],textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).hintColor,fontSize:13,height:1.6))],
      const SizedBox(height:14), Row(children: [Text('$current / $target',style:const TextStyle(fontWeight:FontWeight.bold,color:green)), const Spacer(), if(done) const Icon(Icons.check_circle,color:green,size:19), TextButton(onPressed:(){setState(()=>counts[id]=0);_save();},child:const Text('إعادة'))]),
      ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:(current/target).clamp(0,1),minHeight:5,backgroundColor:green.withOpacity(.12),color:green)), const SizedBox(height:12),
      FilledButton(onPressed:done?null:(){HapticFeedback.selectionClick();setState(()=>counts[id]=current+1);_save();},style:FilledButton.styleFrom(backgroundColor:green,disabledBackgroundColor:green.withOpacity(.12),foregroundColor:Colors.white),child:Text(done?'تمّ الذكر':'اضغط للتكرار')),
    ]));
  }
  Widget _tasbeehPage() => ListView(padding: const EdgeInsets.all(18), children: [Container(padding: const EdgeInsets.fromLTRB(20,24,20,26), decoration:_glass(gradient:true), child:Column(children:[
    const Text('المسبحة الإلكترونية',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)), const SizedBox(height:6), Text('سَبِّح على إيقاعك، دون استعجال',style:TextStyle(color:Theme.of(context).hintColor)), const SizedBox(height:28),
    SizedBox(width:250,height:250,child:Stack(alignment:Alignment.center,children:[SizedBox.expand(child:CircularProgressIndicator(value:(tasbeeh/goal).clamp(0,1),strokeWidth:9,backgroundColor:green.withOpacity(.12),color:green,strokeCap:StrokeCap.round)),InkWell(onTap:_incrementTasbeeh,borderRadius:BorderRadius.circular(120),child:Container(width:205,height:205,decoration:BoxDecoration(shape:BoxShape.circle,color:Theme.of(context).cardColor.withOpacity(.72),boxShadow:[BoxShadow(color:green.withOpacity(.10),blurRadius:28,spreadRadius:4)]),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('$tasbeeh',style:const TextStyle(fontSize:54,fontWeight:FontWeight.w800)),const Text('اضغط للتسبيح',style:TextStyle(color:green,fontWeight:FontWeight.w600))])))])),
    const SizedBox(height:24), const Text('اختر هدفك',style:TextStyle(fontWeight:FontWeight.bold)), const SizedBox(height:12),
    Wrap(spacing:12, children: [33,66,99].map((v) => ChoiceChip(label: Text('$v'), selected: goal == v, onSelected: (_) { setState(() => goal = v); _save(); })).toList()),
    const SizedBox(height:22),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){setState(()=>tasbeeh=tasbeeh>0?tasbeeh-1:0);_save();},icon:const Icon(Icons.remove),label:const Text('إنقاص'))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:(){setState(()=>tasbeeh=0);_save();},icon:const Icon(Icons.refresh),label:const Text('تصفير')))]),
    if(tasbeeh>=goal) const Padding(padding:EdgeInsets.only(top:18),child:Text('ما شاء الله، أتممت الهدف!',style:TextStyle(color:green,fontWeight:FontWeight.bold))),
  ]))]);
  void _incrementTasbeeh(){HapticFeedback.selectionClick();setState(()=>tasbeeh++);_save();}
  Widget _more() => ListView(padding:const EdgeInsets.all(16),children:[_sectionTitle('المزيد',Icons.grid_view_rounded),const SizedBox(height:12),_moreTile('مواقيت الصلاة','مواقيت اليوم في سطيف',Icons.access_time,(){_showPrayer();}),_moreTile('القرآن الكريم','قسم القرآن – يحتاج إضافة مصدر المصحف',Icons.menu_book,(){_showInfo('القرآن الكريم','هذه النسخة الأولى من التحويل. لم يكن محتوى المصحف كاملاً ضمن ملف HTML المرفق، لذلك لم أضع نصاً قرآنياً ناقصاً أو غير موثّق.');}),_moreTile('الأدعية','أدعية مأثورة',Icons.volunteer_activism,(){_showInfo('الأدعية','سيضاف قسم الأدعية عند توفير نصوصه من المصدر.');}),_moreTile('إعدادات المظهر',widget.dark?'التبديل إلى الوضع الفاتح':'التبديل إلى الوضع الداكن',Icons.palette_outlined,widget.onTheme),_moreTile('حول التطبيق','أذكار – إصدار Flutter Native',Icons.info_outline,()=>_showInfo('حول التطبيق','تطبيق أذكار بواجهة Flutter Native، مع حفظ محلي للتقدم والمفضلة.'))]);
  Widget _moreTile(String title,String subtitle,IconData icon,VoidCallback tap)=>Container(margin:const EdgeInsets.only(bottom:10),decoration:_glass(),child:ListTile(onTap:tap,leading:CircleAvatar(backgroundColor:green.withOpacity(.12),child:Icon(icon,color:green)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_left)));
  Widget _prayerCard()=>Container(padding:const EdgeInsets.all(16),decoration:_glass(),child:Column(children:[if(loadingPrayer) const LinearProgressIndicator(minHeight:2),...['الفجر','الشروق','الظهر','العصر','المغرب','العشاء'].map((name)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Icon(Icons.circle,size:7,color:green),const SizedBox(width:10),Expanded(child:Text(name)),Text(prayerTimes[name]??'—',style:const TextStyle(fontWeight:FontWeight.bold,fontFeatures:[FontFeature.tabularFigures()]))]))),const Divider(),TextButton.icon(onPressed:_loadPrayer,icon:const Icon(Icons.refresh),label:const Text('تحديث المواقيت'))]));
  void _showPrayer()=>showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('مواقيت الصلاة – سطيف',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),_prayerCard()]))));
  void _showInfo(String title,String body)=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(title),content:Text(body),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('حسناً'))]));
  Widget _sectionTitle(String title,IconData icon)=>Row(children:[Icon(icon,color:green),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))]);
  BoxDecoration _glass({bool gradient=false})=>BoxDecoration(color:gradient?null:Theme.of(context).cardColor.withOpacity(widget.dark ? .72 : .72),gradient:gradient?LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Theme.of(context).cardColor.withOpacity(.96),green.withOpacity(widget.dark ? .10 : .055)]):null,borderRadius:BorderRadius.circular(24),border:Border.all(color:Theme.of(context).colorScheme.onSurface.withOpacity(.07)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(widget.dark ? .12 : .035),blurRadius:22,offset:const Offset(0,8))]);
}
