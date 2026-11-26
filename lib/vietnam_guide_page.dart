import 'package:flutter/material.dart';

/// Vietnam Guide: 10 cities, 10 places per city, recurring cultural events.
/// Place photos currently load from the internet; they can be switched to local assets later.
class VietnamGuidePage extends StatelessWidget {
  final String languageCode;
  const VietnamGuidePage({super.key, required this.languageCode});

  bool get vi => languageCode == 'vi';
  String t(String a, String b) => vi ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        title: const Text('Vietnam Guide',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        foregroundColor: const Color(0xFF7A2E6E),
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Khám phá 10 thành phố Việt Nam',
                      'Discover 10 Vietnamese cities'),
                      style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900,
                        color: Color(0xFF64265D))),
                  const SizedBox(height: 6),
                  Text(t(
                    'Khám phá những địa danh nổi tiếng, văn hóa và trải nghiệm đặc sắc của Việt Nam.',
                    'Explore famous landmarks, culture and memorable experiences across Vietnam.'),
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cities.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12,
                      mainAxisSpacing: 14, childAspectRatio: .88),
                    itemBuilder: (context, i) {
                      final city = _cities[i];
                      return _CityTile(
                        city: city, isVi: vi,
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                            _CityPage(city: city, isVi: vi))),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    height: 218,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      boxShadow: [BoxShadow(
        color: const Color(0xFF7A2E6E).withOpacity(.18),
        blurRadius: 18, offset: const Offset(0, 8))]),
    child: Stack(fit: StackFit.expand, children: [
      const _Photo(query: 'Vietnam landscape travel', tint: Color(0xFFB65A78)),
      DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(.72)]))),
      Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('VIETNAM', style: TextStyle(color: Colors.white,
              fontSize: 30, letterSpacing: 2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(t('Vẻ đẹp quê hương qua từng điểm đến',
              'The beauty of Vietnam, one destination at a time'),
              style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w600)),
          ])),
    ]),
  );
}

class _CityTile extends StatelessWidget {
  final _City city;
  final bool isVi;
  final VoidCallback onTap;
  const _CityTile({required this.city, required this.isVi, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          _Photo(query: city.photo, tint: city.color),
          Align(alignment: Alignment.bottomCenter, child: Container(height: 65,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(.65)])))),
          Positioned(left: 11, bottom: 10,
            child: Text(city.vi, style: const TextStyle(color: Colors.white,
              fontSize: 19, fontWeight: FontWeight.w900))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
          child: Row(children: [
            Expanded(child: Text(city.en, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6D3267),
                fontSize: 13, fontWeight: FontWeight.w800))),
            const Icon(Icons.arrow_forward_rounded,
              color: Color(0xFFB34A82), size: 18),
          ])),
      ])),
  );
}

class _CityPage extends StatelessWidget {
  final _City city;
  final bool isVi;
  const _CityPage({required this.city, required this.isVi});
  String t(String a, String b) => isVi ? a : b;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8FB),
    appBar: AppBar(title: Text(isVi ? city.vi : city.en,
      style: const TextStyle(fontWeight: FontWeight.w900)),
      centerTitle: true, foregroundColor: const Color(0xFF7A2E6E),
      backgroundColor: const Color(0xFFFFF8FB), elevation: 0),
    body: CustomScrollView(physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(23),
                child: SizedBox(height: 205, width: double.infinity,
                  child: _Photo(query: city.photo, tint: city.color))),
              const SizedBox(height: 13),
              Text(isVi ? city.introVi : city.introEn,
                style: TextStyle(color: Colors.grey.shade800,
                  height: 1.5, fontSize: 14)),
              const SizedBox(height: 22),
              Text(t('10 địa điểm nổi bật', '10 places to discover'),
                style: const TextStyle(fontSize: 21,
                  fontWeight: FontWeight.w900, color: Color(0xFF64265D))),
              const SizedBox(height: 12),
            ]))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (context, i) => _PlaceCard(place: city.places[i], city: city,
              number: i + 1, isVi: isVi, tint: city.color),
            childCount: city.places.length))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: _Events(events: city.events, isVi: isVi, tint: city.color))),
      ]),
  );
}

class _PlaceCard extends StatelessWidget {
  final _Place place;
  final _City city;
  final int number;
  final bool isVi;
  final Color tint;
  const _PlaceCard({required this.place, required this.city, required this.number,
    required this.isVi, required this.tint});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045),
        blurRadius: 12, offset: const Offset(0, 5))]),
    clipBehavior: Clip.antiAlias,
    child: Material(color: Colors.transparent, child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
        _PlaceDetailPage(city: city, place: place, isVi: isVi, tint: tint))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 178, width: double.infinity,
        child: _Photo(query: place.photo, tint: tint)),
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 14, backgroundColor: tint.withOpacity(.13),
                child: Text('$number', style: TextStyle(color: tint,
                  fontWeight: FontWeight.w900, fontSize: 12))),
              const SizedBox(width: 9),
              Expanded(child: Text(isVi ? place.vi : place.en,
                style: const TextStyle(color: Color(0xFF64265D),
                  fontSize: 17, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            Text(isVi ? place.descVi : place.descEn,
              style: TextStyle(color: Colors.grey.shade700,
                height: 1.45, fontSize: 13)),
            const SizedBox(height: 9),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_rounded, size: 17, color: tint),
              const SizedBox(width: 4),
              Expanded(child: Text(isVi ? place.addressVi : place.addressEn,
                style: TextStyle(color: Colors.grey.shade600,
                  fontSize: 12, height: 1.35))),
            ]),
          ])),
    ]))),
  );
}

class _PlaceDetailPage extends StatelessWidget {
  final _City city;
  final _Place place;
  final bool isVi;
  final Color tint;
  const _PlaceDetailPage({required this.city, required this.place,
    required this.isVi, required this.tint});

  @override
  Widget build(BuildContext context) {
    final title = isVi ? place.vi : place.en;
    final description = isVi ? place.descVi : place.descEn;
    final cityName = isVi ? city.vi : city.en;
    final cityIntro = isVi ? city.introVi : city.introEn;
    final address = isVi ? place.addressVi : place.addressEn;

    // Four clear reading sections are shown for every place. The text uses
    // verified place/city information already present in the guide and avoids
    // inventing exact dates or legends when those details are not supplied.
    final about = isVi
        ? '$description $title nằm tại $address. Đây là một điểm đến giúp du khách hiểu thêm về cảnh quan, kiến trúc và nhịp sống của $cityName. Khi đến đây, bạn có thể dành thời gian quan sát không gian xung quanh thay vì chỉ chụp ảnh rồi rời đi.'
        : '$description $title is located at $address. It offers visitors a way to understand the landscape, architecture and everyday character of $cityName. Take time to explore the surroundings rather than treating it only as a photo stop.';
    final history = isVi
        ? 'Để hiểu địa điểm này trong bối cảnh rộng hơn, hãy nhìn vào lịch sử hình thành và phát triển của $cityName: $cityIntro Tùy tính chất của từng địa điểm, dấu tích có thể được thể hiện qua kiến trúc, cách quy hoạch, hiện vật, cảnh quan hoặc những câu chuyện được người dân địa phương lưu truyền. Các mốc thời gian và sự kiện cụ thể nên được đối chiếu với bảng giới thiệu tại di tích hoặc nguồn chính thức tại điểm tham quan.'
        : 'To understand this place in a wider context, consider the history and development of $cityName: $cityIntro Depending on the site, its past may be reflected in its architecture, layout, objects, landscape or stories passed down by local communities. Check the on-site interpretation or official visitor information for precise dates and historical events.';
    final culture = isVi
        ? 'Địa điểm này cũng phản ánh một phần bản sắc của $cityName. Hãy chú ý cách người dân sử dụng và gìn giữ không gian, những tập quán sinh hoạt quanh khu vực, cũng như sự kết hợp giữa truyền thống và đời sống hiện đại. Nếu đây là nơi thờ tự hoặc di tích, cần giữ thái độ trang nghiêm, ăn mặc phù hợp và tôn trọng hoạt động của người dân.'
        : 'This place also reflects part of the identity of $cityName. Notice how local people use and care for the space, the everyday customs around it, and the way tradition meets modern life. If it is a place of worship or a heritage site, dress appropriately, behave respectfully and avoid disrupting local activities.';
    final tips = isVi
        ? 'Bạn nên kiểm tra giờ mở cửa, giá vé và quy định chụp ảnh trước khi đi vì thông tin có thể thay đổi. Hãy dành đủ thời gian đọc bảng giới thiệu, đi bộ khám phá khu vực lân cận và hỏi hướng dẫn viên khi muốn biết sâu hơn. Không xả rác, không làm hư hại công trình hay lấy bất kỳ hiện vật nào làm kỷ niệm.'
        : 'Check opening hours, admission fees and photography rules before visiting, as details can change. Allow time to read the information panels, explore nearby streets and ask a local guide if you want to learn more. Do not litter, damage structures or remove objects as souvenirs.';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(title: Text(title, maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        foregroundColor: const Color(0xFF7A2E6E),
        backgroundColor: const Color(0xFFFFF8FB), elevation: 0),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(22),
            child: SizedBox(height: 235,
              child: _Photo(query: place.photo, tint: tint))),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 24,
            fontWeight: FontWeight.w900, color: Color(0xFF64265D))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.location_on_rounded, color: tint, size: 19),
            const SizedBox(width: 5),
            Expanded(child: Text(address, style: TextStyle(
              color: Colors.grey.shade700, height: 1.4))),
          ]),
          const SizedBox(height: 20),
          _detailSection(isVi ? '1. Giới thiệu địa điểm' : '1. About this place',
            about, Icons.info_outline_rounded),
          const SizedBox(height: 14),
          _detailSection(isVi ? '2. Lịch sử và câu chuyện' : '2. History and stories',
            history, Icons.account_balance_rounded),
          const SizedBox(height: 14),
          _detailSection(isVi ? '3. Giá trị văn hoá và đời sống địa phương' : '3. Culture and local life',
            culture, Icons.diversity_3_rounded),
          const SizedBox(height: 14),
          _detailSection(isVi ? '4. Trải nghiệm và lưu ý khi tham quan' : '4. Visitor experience and tips',
            tips, Icons.explore_rounded),
        ]),
    );
  }

  Widget _detailSection(String heading, String body, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: tint.withOpacity(.12))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: tint, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(heading, style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w900, color: Color(0xFF64265D))))]),
      const SizedBox(height: 9),
      Text(body, style: TextStyle(color: Colors.grey.shade800,
        height: 1.6, fontSize: 13.5)),
    ]),
  );
}

class _Events extends StatelessWidget {
  final List<_Event> events;
  final bool isVi;
  final Color tint;
  const _Events({required this.events, required this.isVi, required this.tint});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isVi ? 'Sự kiện thường xuyên' : 'Regular events & experiences',
        style: const TextStyle(color: Color(0xFF64265D),
          fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(isVi ? 'Những hoạt động và màn trình diễn thường diễn ra tại thành phố này.'
        : 'Recurring activities and performances in this city.',
        style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
      const SizedBox(height: 13),
      if (events.isEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(18)),
          child: Text(isVi
            ? 'Thông tin sự kiện định kỳ tại thành phố này sẽ được bổ sung. Lịch tổ chức có thể thay đổi theo từng thời điểm.'
            : 'Recurring event information for this city will be added. Schedules may change from time to time.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45)))
      else
        ...events.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tint.withOpacity(.13))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 43, height: 43,
              decoration: BoxDecoration(color: tint.withOpacity(.12),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.event_available_rounded, color: tint)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isVi ? e.vi : e.en, style: const TextStyle(
                  color: Color(0xFF64265D), fontWeight: FontWeight.w900,
                  fontSize: 15)),
                const SizedBox(height: 5),
                Text(isVi ? e.scheduleVi : e.scheduleEn,
                  style: TextStyle(color: tint, fontWeight: FontWeight.w800,
                    fontSize: 12)),
                const SizedBox(height: 5),
                Text(isVi ? e.descVi : e.descEn,
                  style: TextStyle(color: Colors.grey.shade700,
                    height: 1.4, fontSize: 12)),
              ])),
          ]))),
      const SizedBox(height: 4),
      Text(isVi
        ? '* Lịch sự kiện chỉ mang tính tham khảo. Vui lòng kiểm tra thông báo địa phương trước khi đến vì thời gian có thể thay đổi.'
        : '* Event schedules are a guide only. Check local updates before visiting, as times may change.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 11,
          height: 1.4, fontStyle: FontStyle.italic)),
    ]);
}

/// Photos are fetched directly over HTTPS. No local asset/download step required.
/// If the image service cannot find a photo, a coloured placeholder is shown.
class _Photo extends StatelessWidget {
  final String query;
  final Color tint;
  const _Photo({required this.query, required this.tint});

  @override
  Widget build(BuildContext context) {
    final url = 'https://loremflickr.com/1000/700/${Uri.encodeComponent(query)}';
    return Image.network(url, width: double.infinity, height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
        ? child
        : Container(color: tint.withOpacity(.13),
            alignment: Alignment.center,
            child: CircularProgressIndicator(strokeWidth: 2, color: tint)),
      errorBuilder: (_, __, ___) => Container(
        color: tint.withOpacity(.18), alignment: Alignment.center,
        child: Icon(Icons.photo_outlined, size: 42, color: tint)));
  }
}

class _City {
  final String vi, en, photo, introVi, introEn;
  final Color color;
  final List<_Place> places;
  final List<_Event> events;
  const _City({required this.vi, required this.en, required this.photo,
    required this.introVi, required this.introEn, required this.color,
    required this.places, this.events = const []});
}
class _Place {
  final String vi, en, descVi, descEn, addressVi, addressEn, photo;
  const _Place(this.vi, this.en, this.descVi, this.descEn,
    this.addressVi, this.addressEn, this.photo);
}
class _Event {
  final String vi, en, scheduleVi, scheduleEn, descVi, descEn;
  const _Event({required this.vi, required this.en,
    required this.scheduleVi, required this.scheduleEn,
    required this.descVi, required this.descEn});
}

const _cities = <_City>[
  _City(vi:'Hà Nội', en:'Hanoi', photo:'Hanoi Hoan Kiem Lake Vietnam',
    introVi:'Thủ đô nghìn năm văn hiến, nổi bật với phố cổ, hồ nước, kiến trúc lịch sử và nét văn hóa miền Bắc.',
    introEn:'Vietnam’s historic capital, known for its Old Quarter, lakes, heritage architecture and northern culture.',
    color:Color(0xFFB66A45), places:[
      _Place('Hồ Hoàn Kiếm','Hoan Kiem Lake','Biểu tượng của Hà Nội, gắn với truyền thuyết Hồ Gươm.','A Hanoi landmark associated with the legend of the restored sword.','Phường Hoàn Kiếm, Hà Nội','Hoan Kiem Ward, Hanoi','Hoan Kiem Lake Hanoi'),
      _Place('Phố cổ Hà Nội','Hanoi Old Quarter','Những con phố lâu đời với nhà cổ, cửa hàng truyền thống và ẩm thực đường phố.','Historic streets with old houses, traditional shops and street food.','Quận Hoàn Kiếm, Hà Nội','Hoan Kiem District, Hanoi','Hanoi Old Quarter street'),
      _Place('Văn Miếu – Quốc Tử Giám','Temple of Literature','Di tích gắn với Nho học và truyền thống hiếu học Việt Nam.','A historic complex linked to learning and Vietnam’s scholarly tradition.','58 Quốc Tử Giám, Đống Đa, Hà Nội','58 Quoc Tu Giam, Dong Da, Hanoi','Temple of Literature Hanoi'),
      _Place('Lăng Chủ tịch Hồ Chí Minh','Ho Chi Minh Mausoleum','Công trình lịch sử quan trọng tại Quảng trường Ba Đình.','An important historic monument at Ba Dinh Square.','Quảng trường Ba Đình, Hà Nội','Ba Dinh Square, Hanoi','Ho Chi Minh Mausoleum Hanoi'),
      _Place('Chùa Một Cột','One Pillar Pagoda','Ngôi chùa có kiến trúc độc đáo được dựng trên một trụ đá.','A distinctive pagoda built on a single stone pillar.','Phố Chùa Một Cột, Ba Đình, Hà Nội','Chua Mot Cot Street, Ba Dinh, Hanoi','One Pillar Pagoda Hanoi'),
      _Place('Nhà thờ Lớn Hà Nội','St Joseph’s Cathedral','Nhà thờ kiến trúc Gothic nổi bật gần khu phố cổ.','A striking Gothic-style cathedral near the Old Quarter.','40 Nhà Chung, Hoàn Kiếm, Hà Nội','40 Nha Chung, Hoan Kiem, Hanoi','St Joseph Cathedral Hanoi'),
      _Place('Hoàng thành Thăng Long','Imperial Citadel of Thang Long','Di sản thế giới lưu giữ dấu tích nhiều triều đại Việt Nam.','A World Heritage site preserving remains of Vietnamese dynasties.','19C Hoàng Diệu, Ba Đình, Hà Nội','19C Hoang Dieu, Ba Dinh, Hanoi','Imperial Citadel Hanoi'),
      _Place('Hồ Tây','West Lake','Hồ nước rộng lớn với nhiều góc ngắm hoàng hôn.','A large lake with beautiful sunset viewpoints.','Khu vực Hồ Tây, Hà Nội','West Lake area, Hanoi','West Lake Hanoi'),
      _Place('Cầu Long Biên','Long Bien Bridge','Cây cầu lịch sử bắc qua sông Hồng.','A historic bridge crossing the Red River.','Bắc qua sông Hồng, Hà Nội','Across the Red River, Hanoi','Long Bien Bridge Hanoi'),
      _Place('Nhà hát Lớn Hà Nội','Hanoi Opera House','Công trình kiến trúc Pháp cổ và địa điểm biểu diễn nghệ thuật.','A French-era architectural landmark and performing arts venue.','1 Tràng Tiền, Hoàn Kiếm, Hà Nội','1 Trang Tien, Hoan Kiem, Hanoi','Hanoi Opera House'),
    ], events:[
      _Event(vi:'Múa rối nước',en:'Water Puppet Theatre',
        scheduleVi:'Có các suất diễn thường xuyên; giờ diễn thay đổi theo ngày.',
        scheduleEn:'Regular performances; showtimes vary by day.',
        descVi:'Nghệ thuật sân khấu dân gian độc đáo của Việt Nam. Kiểm tra lịch tại nhà hát trước khi đến.',
        descEn:'A unique Vietnamese folk performance art. Check the theatre schedule before visiting.'),
    ]),
  _City(vi:'Hạ Long',en:'Ha Long',photo:'Ha Long Bay limestone islands Vietnam',
    introVi:'Vùng biển nổi tiếng với hàng nghìn đảo đá vôi, làn nước xanh và cảnh quan thiên nhiên kỳ vĩ.',
    introEn:'A coastal destination famed for limestone islands, emerald waters and spectacular scenery.',
    color:Color(0xFF278C9A),places:[
      _Place('Vịnh Hạ Long','Ha Long Bay','Di sản thiên nhiên thế giới với quần thể đảo đá vôi giữa biển.','A World Heritage seascape of limestone islands rising from the sea.','Thành phố Hạ Long, Quảng Ninh','Ha Long City, Quang Ninh','Ha Long Bay Vietnam'),
      _Place('Đảo Ti Tốp','Titov Island','Đảo nhỏ có bãi tắm và điểm ngắm toàn cảnh vịnh.','An island with a beach and a viewpoint over the bay.','Vịnh Hạ Long, Quảng Ninh','Ha Long Bay, Quang Ninh','Titov Island Ha Long'),
      _Place('Hang Sửng Sốt','Sung Sot Cave','Hang động rộng lớn với nhiều khối thạch nhũ độc đáo.','A spacious cave with impressive rock formations.','Vịnh Hạ Long, Quảng Ninh','Ha Long Bay, Quang Ninh','Sung Sot Cave'),
      _Place('Hang Đầu Gỗ','Dau Go Cave','Hang động nổi bật với các khoang rộng và nhũ đá.','A cave known for large chambers and stalactites.','Vịnh Hạ Long, Quảng Ninh','Ha Long Bay, Quang Ninh','Dau Go Cave Ha Long'),
      _Place('Đảo Soi Sim','Soi Sim Island','Hòn đảo xanh với bãi cát và cảnh quan yên bình.','A green island with a sandy beach and peaceful scenery.','Vịnh Hạ Long, Quảng Ninh','Ha Long Bay, Quang Ninh','Soi Sim Island'),
      _Place('Bảo tàng Quảng Ninh','Quang Ninh Museum','Bảo tàng kiến trúc hiện đại giới thiệu lịch sử địa phương.','A modern museum showcasing local history.','Trần Quốc Nghiễn, Hạ Long','Tran Quoc Nghien, Ha Long','Quang Ninh Museum'),
      _Place('Bãi Cháy','Bai Chay Beach','Khu du lịch biển với bãi tắm và dịch vụ nghỉ dưỡng.','A seaside area with a beach and resort facilities.','Bãi Cháy, Hạ Long','Bai Chay, Ha Long','Bai Chay beach'),
      _Place('Núi Bài Thơ','Bai Tho Mountain','Điểm cao ngắm thành phố và vịnh; kiểm tra tình trạng mở cửa trước khi đi.','A viewpoint over the city and bay; check access before visiting.','Trung tâm Hạ Long','Central Ha Long','Bai Tho Mountain'),
      _Place('Làng chài Cửa Vạn','Cua Van Fishing Village','Làng chài truyền thống phản ánh đời sống cư dân vùng vịnh.','A traditional fishing village reflecting life on the bay.','Vịnh Hạ Long, Quảng Ninh','Ha Long Bay, Quang Ninh','Cua Van fishing village'),
      _Place('Sun World Hạ Long','Sun World Ha Long','Tổ hợp vui chơi với cáp treo và nhiều hoạt động giải trí.','An entertainment complex with a cable car and attractions.','Bãi Cháy, Hạ Long','Bai Chay, Ha Long','Sun World Ha Long'),
    ]),
  _City(vi:'Sa Pa',en:'Sapa',photo:'Sapa Vietnam rice terraces mountains',
    introVi:'Thị trấn vùng cao nổi bật với núi non, ruộng bậc thang, bản làng và văn hóa các dân tộc.',
    introEn:'A mountain town known for peaks, terraced fields, village life and ethnic cultures.',
    color:Color(0xFF5C8B62),places:[
      _Place('Đỉnh Fansipan','Fansipan Peak','Đỉnh núi nổi tiếng của Việt Nam, có thể tiếp cận bằng cáp treo.','Vietnam’s famous high mountain peak, accessible by cable car.','Sun World Fansipan Legend, Sa Pa','Sun World Fansipan Legend, Sapa','Fansipan peak'),
      _Place('Bản Cát Cát','Cat Cat Village','Bản làng người H’Mông với nhà truyền thống và nghề thủ công.','A Hmong village with traditional houses and handicrafts.','Xã Hoàng Liên, Sa Pa','Hoang Lien Commune, Sapa','Cat Cat Village Sapa'),
      _Place('Thung lũng Mường Hoa','Muong Hoa Valley','Thung lũng nổi tiếng với ruộng bậc thang và cảnh núi.','A scenic valley known for terraced fields and mountains.','Khu vực Mường Hoa, Sa Pa','Muong Hoa area, Sapa','Muong Hoa Valley'),
      _Place('Nhà thờ đá Sa Pa','Sapa Stone Church','Công trình kiến trúc cổ nằm ngay trung tâm thị trấn.','An old stone church in the town centre.','Trung tâm Sa Pa, Lào Cai','Sapa Town Centre, Lao Cai','Sapa Stone Church'),
      _Place('Đèo Ô Quy Hồ','O Quy Ho Pass','Cung đèo nổi tiếng với cảnh núi rừng hùng vĩ.','A famous mountain pass with sweeping views.','Quốc lộ 4D, Sa Pa','National Highway 4D, Sapa','O Quy Ho Pass'),
      _Place('Thác Bạc','Silver Waterfall','Thác nước giữa núi rừng, đẹp vào mùa nước.','A waterfall among forested mountains.','Quốc lộ 4D, Sa Pa','National Highway 4D, Sapa','Silver Waterfall Sapa'),
      _Place('Thác Tình Yêu','Love Waterfall','Thác nước trong rừng với đường đi bộ thiên nhiên.','A forest waterfall reached by a nature walk.','Khu vực Trạm Tôn, Sa Pa','Tram Ton area, Sapa','Love Waterfall Sapa'),
      _Place('Bản Tả Van','Ta Van Village','Bản làng yên bình giữa thung lũng, tìm hiểu đời sống địa phương.','A peaceful valley village to discover local life.','Xã Tả Van, Sa Pa','Ta Van Commune, Sapa','Ta Van village'),
      _Place('Núi Hàm Rồng','Ham Rong Mountain','Khu tham quan có vườn hoa và điểm ngắm toàn cảnh thị trấn.','A sightseeing area with gardens and town viewpoints.','Trung tâm Sa Pa','Central Sapa','Ham Rong Mountain'),
      _Place('Chợ Sa Pa','Sapa Market','Không gian tìm hiểu sản vật, thổ cẩm và sinh hoạt vùng cao.','A place to discover local produce, textiles and highland life.','Trung tâm Sa Pa','Central Sapa','Sapa market'),
    ]),
  _City(vi:'Huế',en:'Hue',photo:'Hue Imperial City Vietnam citadel',
    introVi:'Cố đô trầm mặc, nổi tiếng với di sản triều Nguyễn, lăng tẩm, chùa cổ và sông Hương.',
    introEn:'The former imperial capital, known for Nguyen Dynasty heritage, royal tombs, pagodas and the Perfume River.',
    color:Color(0xFF9870A5),places:[
      _Place('Đại Nội Huế','Imperial City of Hue','Quần thể cung điện và thành quách của triều Nguyễn.','The palace and citadel complex of the Nguyen emperors.','Đường 23 Tháng 8, Huế','23 Thang 8 Street, Hue','Hue Imperial City'),
      _Place('Chùa Thiên Mụ','Thien Mu Pagoda','Ngôi chùa cổ bên sông Hương với tháp Phước Duyên.','An ancient pagoda by the Perfume River.','Đồi Hà Khê, Kim Long, Huế','Ha Khe Hill, Kim Long, Hue','Thien Mu Pagoda'),
      _Place('Lăng Khải Định','Khai Dinh Tomb','Lăng tẩm kết hợp phong cách kiến trúc Á Đông và châu Âu.','A royal tomb blending East Asian and European styles.','Xã Thủy Bằng, Huế','Thuy Bang Commune, Hue','Khai Dinh Tomb'),
      _Place('Lăng Tự Đức','Tu Duc Tomb','Quần thể lăng tẩm hài hòa với hồ nước và đồi thông.','A tranquil royal complex with lakes and pine hills.','Phường Thủy Xuân, Huế','Thuy Xuan Ward, Hue','Tu Duc Tomb'),
      _Place('Cầu Trường Tiền','Truong Tien Bridge','Cây cầu biểu tượng bắc qua sông Hương.','An iconic bridge crossing the Perfume River.','Trung tâm thành phố Huế','Hue city centre','Truong Tien Bridge Hue'),
      _Place('Sông Hương','Perfume River','Dòng sông thơ mộng gắn với cảnh quan và đời sống Huế.','A poetic river central to Hue’s landscape and daily life.','Trung tâm thành phố Huế','Hue city centre','Perfume River Hue'),
      _Place('Chợ Đông Ba','Dong Ba Market','Khu chợ truyền thống để khám phá đặc sản địa phương.','A traditional market for local specialties.','2 Trần Hưng Đạo, Huế','2 Tran Hung Dao, Hue','Dong Ba Market'),
      _Place('Đồi Vọng Cảnh','Vong Canh Hill','Điểm ngắm sông Hương và rừng thông từ trên cao.','A viewpoint over the Perfume River and pine forest.','Phường Thủy Xuân, Huế','Thuy Xuan Ward, Hue','Vong Canh Hill'),
      _Place('Điện Hòn Chén','Hon Chen Temple','Di tích tín ngưỡng bên sông Hương, gắn với văn hóa dân gian.','A riverside religious heritage site linked to folk traditions.','Núi Ngọc Trản, Huế','Ngoc Tran Mountain, Hue','Hon Chen Temple'),
      _Place('Phố đi bộ Nguyễn Đình Chiểu','Nguyen Dinh Chieu Walking Street','Không gian dạo bộ ven sông với cảnh đẹp về đêm.','A riverside promenade with scenic evening views.','Bờ nam sông Hương, Huế','South bank of Perfume River, Hue','Nguyen Dinh Chieu walking street'),
    ]),
  _City(vi:'Đà Nẵng',en:'Da Nang',photo:'Da Nang Dragon Bridge Han River Vietnam',
    introVi:'Thành phố biển năng động với những cây cầu biểu tượng, bãi biển đẹp và thắng cảnh thiên nhiên.',
    introEn:'A vibrant coastal city with iconic bridges, beautiful beaches and striking natural attractions.',
    color:Color(0xFF248F9D),places:[
      _Place('Cầu Rồng','Dragon Bridge','Cầu hình rồng nổi tiếng với màn phun lửa và phun nước vào một số tối cuối tuần.','A dragon-shaped bridge known for its fire and water show on selected weekend nights.','Đường Nguyễn Văn Linh, Đà Nẵng','Nguyen Van Linh Street, Da Nang','Dragon Bridge fire show Da Nang'),
      _Place('Cầu Vàng','Golden Bridge','Cây cầu nổi tiếng được nâng đỡ bởi đôi bàn tay khổng lồ ở Bà Nà.','A celebrated bridge held by giant stone hands in Ba Na Hills.','Sun World Bà Nà Hills, Đà Nẵng','Sun World Ba Na Hills, Da Nang','Golden Bridge Ba Na Hills'),
      _Place('Biển Mỹ Khê','My Khe Beach','Bãi biển dài với cát mịn, thích hợp tắm biển và ngắm bình minh.','A long sandy beach popular for swimming and sunrise views.','Đường Võ Nguyên Giáp, Đà Nẵng','Vo Nguyen Giap Street, Da Nang','My Khe Beach Da Nang'),
      _Place('Ngũ Hành Sơn','Marble Mountains','Quần thể núi đá vôi với hang động, chùa và điểm ngắm cảnh.','Limestone hills with caves, pagodas and viewpoints.','Phường Hòa Hải, Đà Nẵng','Hoa Hai Ward, Da Nang','Marble Mountains Da Nang'),
      _Place('Bán đảo Sơn Trà','Son Tra Peninsula','Khu thiên nhiên với rừng, biển và nhiều điểm ngắm toàn cảnh.','A nature area with forest, coastline and panoramic viewpoints.','Quận Sơn Trà, Đà Nẵng','Son Tra District, Da Nang','Son Tra Peninsula Da Nang'),
      _Place('Chùa Linh Ứng','Linh Ung Pagoda','Ngôi chùa nổi bật với tượng Quan Âm lớn nhìn ra biển.','A pagoda with a large Lady Buddha statue overlooking the sea.','Bãi Bụt, Sơn Trà, Đà Nẵng','Bai But, Son Tra, Da Nang','Linh Ung Pagoda Da Nang'),
      _Place('Cầu sông Hàn','Han River Bridge','Cây cầu quay độc đáo, một biểu tượng của thành phố.','A distinctive swing bridge and city landmark.','Trung tâm Đà Nẵng','Central Da Nang','Han River Swing Bridge'),
      _Place('Chợ Hàn','Han Market','Khu chợ truyền thống nổi tiếng với đặc sản và quà lưu niệm.','A traditional market known for specialties and souvenirs.','119 Trần Phú, Đà Nẵng','119 Tran Phu, Da Nang','Han Market Da Nang'),
      _Place('Bảo tàng Điêu khắc Chăm','Museum of Cham Sculpture','Nơi lưu giữ bộ sưu tập hiện vật nghệ thuật Chăm.','A museum preserving a collection of Cham art and artefacts.','2 đường 2 Tháng 9, Đà Nẵng','2 September 2 Street, Da Nang','Cham Sculpture Museum'),
      _Place('Phố đi bộ Bạch Đằng','Bach Dang Riverside Walk','Tuyến dạo bộ ven sông với cảnh cầu và thành phố về đêm.','A riverside promenade with bridge and city views at night.','Đường Bạch Đằng, Đà Nẵng','Bach Dang Street, Da Nang','Bach Dang riverside Da Nang'),
    ],events:[
      _Event(vi:'Cầu Rồng phun lửa và nước',en:'Dragon Bridge Fire & Water Show',
        scheduleVi:'Thông thường tối thứ Sáu, thứ Bảy và Chủ Nhật, khoảng 9:00 PM.',
        scheduleEn:'Typically Friday, Saturday and Sunday evenings, around 9:00 PM.',
        descVi:'Màn trình diễn tại đầu rồng trên sông Hàn. Nên đến sớm để chọn vị trí xem; lịch có thể thay đổi.',
        descEn:'A performance at the dragon’s head over the Han River. Arrive early; schedules may change.'),
      _Event(vi:'Cầu sông Hàn quay',en:'Han River Bridge Swing',
        scheduleVi:'Thường vào đêm cuối tuần, khoảng 11:00 PM; thời gian có thể thay đổi.',
        scheduleEn:'Usually on weekend nights, around 11:00 PM; timing may vary.',
        descVi:'Hoạt động quay nhịp giữa của cầu là trải nghiệm đặc trưng của Đà Nẵng.',
        descEn:'The bridge’s rotating centre span is a distinctive Da Nang experience.'),
    ]),
  _City(vi:'Hội An',en:'Hoi An',photo:'Hoi An ancient town lantern river Vietnam',
    introVi:'Phố cổ duyên dáng với mái nhà vàng, đèn lồng, kiến trúc giao thoa và không gian ven sông.',
    introEn:'A charming heritage town of yellow houses, lanterns, historic architecture and riverside scenes.',
    color:Color(0xFFC58A42),places:[
      _Place('Phố cổ Hội An','Hoi An Ancient Town','Khu phố di sản với nhà cổ, đường nhỏ và đèn lồng rực rỡ.','A heritage quarter of old houses, narrow streets and colourful lanterns.','Phường Minh An, Hội An','Minh An Ward, Hoi An','Hoi An Ancient Town lanterns'),
      _Place('Chùa Cầu','Japanese Covered Bridge','Cây cầu có mái che mang dấu ấn giao thương Nhật Bản xưa.','A covered bridge reflecting historic Japanese trading links.','Trung tâm phố cổ Hội An','Hoi An Ancient Town centre','Japanese Covered Bridge Hoi An'),
      _Place('Hội quán Phúc Kiến','Fujian Assembly Hall','Hội quán nổi bật với kiến trúc và trang trí truyền thống.','An ornate assembly hall with traditional architecture.','46 Trần Phú, Hội An','46 Tran Phu, Hoi An','Fujian Assembly Hall Hoi An'),
      _Place('Nhà cổ Tấn Ký','Tan Ky Old House','Ngôi nhà cổ tiêu biểu cho kiến trúc thương nhân Hội An.','A preserved merchant house representing historic Hoi An architecture.','101 Nguyễn Thái Học, Hội An','101 Nguyen Thai Hoc, Hoi An','Tan Ky Old House'),
      _Place('Sông Hoài','Hoai River','Dòng sông thơ mộng với thuyền nhỏ và ánh đèn lồng về đêm.','A picturesque river with small boats and lantern reflections.','Khu phố cổ Hội An','Hoi An Ancient Town','Hoai River Hoi An'),
      _Place('Chợ Hội An','Hoi An Market','Khu chợ địa phương với sản vật và món ăn miền Trung.','A local market with regional produce and central Vietnamese food.','19 Trần Phú, Hội An','19 Tran Phu, Hoi An','Hoi An Central Market'),
      _Place('Biển An Bàng','An Bang Beach','Bãi biển thư giãn với cát trắng và hàng quán ven biển.','A relaxed beach with pale sand and seaside venues.','Phường Cẩm An, Hội An','Cam An Ward, Hoi An','An Bang Beach Hoi An'),
      _Place('Làng rau Trà Quế','Tra Que Vegetable Village','Làng nghề trồng rau truyền thống với vườn xanh.','A traditional vegetable-growing village with green gardens.','Xã Cẩm Hà, Hội An','Cam Ha Commune, Hoi An','Tra Que vegetable village'),
      _Place('Rừng dừa Bảy Mẫu','Bay Mau Coconut Forest','Rừng dừa nước với trải nghiệm thuyền thúng đặc trưng.','A nipa palm waterway known for round basket boat rides.','Xã Cẩm Thanh, Hội An','Cam Thanh Commune, Hoi An','Bay Mau coconut forest'),
      _Place('Làng gốm Thanh Hà','Thanh Ha Pottery Village','Làng nghề gốm lâu đời với sản phẩm thủ công truyền thống.','A long-established pottery village producing handmade ceramics.','Phường Thanh Hà, Hội An','Thanh Ha Ward, Hoi An','Thanh Ha pottery village'),
    ],events:[
      _Event(vi:'Đêm phố cổ và lễ hội đèn lồng',en:'Hoi An Lantern Festival',
        scheduleVi:'Đêm 14 âm lịch hằng tháng thường gắn với hoạt động đèn lồng.',
        scheduleEn:'The 14th day of each lunar month is traditionally associated with lantern-night activities.',
        descVi:'Phố cổ thắp sáng bằng đèn lồng và có hoạt động văn hóa; chương trình cụ thể tùy từng tháng.',
        descEn:'The Old Town glows with lanterns and cultural activities; the programme varies monthly.'),
    ]),
  _City(vi:'Nha Trang',en:'Nha Trang',photo:'Nha Trang beach bay Vietnam',
    introVi:'Thành phố biển nổi tiếng với vịnh đẹp, đảo xanh, bãi cát dài và di sản văn hóa Chăm.',
    introEn:'A seaside city known for its bay, islands, sandy beaches and Cham heritage.',
    color:Color(0xFF2A9AB0),places:[
      _Place('Bãi biển Nha Trang','Nha Trang Beach','Bãi biển trung tâm với bờ biển dài và hàng dừa.','The central beach with a long shoreline and palm-lined promenade.','Đường Trần Phú, Nha Trang','Tran Phu Street, Nha Trang','Nha Trang beach'),
      _Place('Tháp Bà Ponagar','Po Nagar Cham Towers','Quần thể tháp Chăm cổ có giá trị lịch sử và tín ngưỡng.','An ancient Cham temple complex of historical significance.','Đường 2 Tháng 4, Nha Trang','2 Thang 4 Street, Nha Trang','Po Nagar Cham Towers'),
      _Place('Hòn Mun','Hon Mun Island','Khu vực biển nổi tiếng với hệ sinh thái san hô.','A marine area known for its coral ecosystem.','Vịnh Nha Trang, Khánh Hòa','Nha Trang Bay, Khanh Hoa','Hon Mun island'),
      _Place('VinWonders Nha Trang','VinWonders Nha Trang','Tổ hợp vui chơi giải trí trên đảo với nhiều trò chơi.','An island amusement complex with rides and attractions.','Đảo Hòn Tre, Nha Trang','Hon Tre Island, Nha Trang','VinWonders Nha Trang'),
      _Place('Chùa Long Sơn','Long Son Pagoda','Ngôi chùa nổi tiếng với tượng Phật trắng trên đồi.','A pagoda known for its large white Buddha statue on the hill.','23 Tháng 10, Nha Trang','23 Thang 10 Street, Nha Trang','Long Son Pagoda'),
      _Place('Viện Hải dương học','National Oceanographic Museum','Nơi tìm hiểu sinh vật biển và nghiên cứu hải dương học.','A place to learn about marine life and ocean research.','1 Cầu Đá, Nha Trang','1 Cau Da, Nha Trang','Oceanographic Museum Nha Trang'),
      _Place('Nhà thờ Núi','Nha Trang Cathedral','Nhà thờ đá mang kiến trúc Gothic trên một ngọn đồi nhỏ.','A Gothic-style stone church set on a small hill.','31 Thái Nguyên, Nha Trang','31 Thai Nguyen, Nha Trang','Nha Trang Cathedral'),
      _Place('Chợ Đầm','Dam Market','Khu chợ nổi tiếng để mua đặc sản và quà địa phương.','A popular market for local specialties and souvenirs.','Đường Phan Bội Châu, Nha Trang','Phan Boi Chau Street, Nha Trang','Dam Market Nha Trang'),
      _Place('Bãi Dài','Bai Dai Beach','Bãi biển thoáng rộng với cát mịn ở phía nam thành phố.','A spacious sandy beach south of the city.','Cam Lâm, Khánh Hòa','Cam Lam, Khanh Hoa','Bai Dai beach'),
      _Place('Hòn Chồng','Hon Chong Promontory','Cụm đá ven biển với góc nhìn ra vịnh Nha Trang.','A coastal rock formation overlooking Nha Trang Bay.','Phường Vĩnh Phước, Nha Trang','Vinh Phuoc Ward, Nha Trang','Hon Chong Nha Trang'),
    ]),
  _City(vi:'Đà Lạt',en:'Da Lat',photo:'Da Lat Xuan Huong lake pine forest Vietnam',
    introVi:'Thành phố cao nguyên mát mẻ, nổi bật với hồ, rừng thông, vườn hoa và kiến trúc cổ.',
    introEn:'A cool highland city known for lakes, pine forests, flower gardens and historic architecture.',
    color:Color(0xFF648C6B),places:[
      _Place('Hồ Xuân Hương','Xuan Huong Lake','Hồ nước hình trăng lưỡi liềm ngay trung tâm thành phố.','A crescent-shaped lake in the heart of the city.','Trung tâm Đà Lạt, Lâm Đồng','Central Da Lat, Lam Dong','Xuan Huong Lake'),
      _Place('Quảng trường Lâm Viên','Lam Vien Square','Không gian công cộng với công trình nụ hoa atiso nổi bật.','A public square known for its giant artichoke-bud structure.','Đường Trần Quốc Toản, Đà Lạt','Tran Quoc Toan Street, Da Lat','Lam Vien Square'),
      _Place('Nhà thờ Con Gà','Dalat Cathedral','Nhà thờ có tháp chuông gắn biểu tượng con gà.','A cathedral with a distinctive rooster symbol atop its bell tower.','15 Trần Phú, Đà Lạt','15 Tran Phu, Da Lat','Dalat Cathedral'),
      _Place('Ga Đà Lạt','Dalat Railway Station','Nhà ga cổ với kiến trúc độc đáo và đầu tàu di sản.','A historic railway station with distinctive architecture.','Quang Trung, Đà Lạt','Quang Trung, Da Lat','Dalat Railway Station'),
      _Place('Thung lũng Tình Yêu','Valley of Love','Khu thắng cảnh với đồi thông, hồ nước và vườn hoa.','A scenic attraction with pine hills, a lake and flower gardens.','7 Mai Anh Đào, Đà Lạt','7 Mai Anh Dao, Da Lat','Valley of Love Da Lat'),
      _Place('Thiền viện Trúc Lâm','Truc Lam Zen Monastery','Thiền viện yên bình nhìn ra hồ Tuyền Lâm.','A peaceful monastery overlooking Tuyen Lam Lake.','Núi Phượng Hoàng, Đà Lạt','Phoenix Mountain, Da Lat','Truc Lam Zen Monastery'),
      _Place('Hồ Tuyền Lâm','Tuyen Lam Lake','Hồ nước rộng giữa rừng thông, phù hợp ngắm cảnh.','A large lake surrounded by pine forest.','Phường 4, Đà Lạt','Ward 4, Da Lat','Tuyen Lam Lake'),
      _Place('Thác Datanla','Datanla Waterfall','Thác nước giữa rừng với các hoạt động ngoài trời.','A forest waterfall with outdoor activities.','Đèo Prenn, Đà Lạt','Prenn Pass, Da Lat','Datanla Waterfall'),
      _Place('Dinh Bảo Đại','Bao Dai Summer Palace','Biệt điện lịch sử gắn với vị vua cuối cùng triều Nguyễn.','A historic summer palace associated with Vietnam’s last emperor.','1 Triệu Việt Vương, Đà Lạt','1 Trieu Viet Vuong, Da Lat','Bao Dai Palace Da Lat'),
      _Place('Chợ Đà Lạt','Dalat Market','Khu chợ trung tâm nổi tiếng với nông sản, hoa và đặc sản.','The central market, known for produce, flowers and local specialties.','Nguyễn Thị Minh Khai, Đà Lạt','Nguyen Thi Minh Khai, Da Lat','Dalat Market'),
    ]),
  _City(vi:'TP. Hồ Chí Minh',en:'Ho Chi Minh City',photo:'Ho Chi Minh City skyline Landmark 81 Vietnam',
    introVi:'Thành phố sôi động với kiến trúc lịch sử, nhịp sống hiện đại, bảo tàng và những khu phố đặc sắc.',
    introEn:'A dynamic metropolis blending historic architecture, modern city life, museums and vibrant neighbourhoods.',
    color:Color(0xFFB56C55),places:[
      _Place('Dinh Độc Lập','Independence Palace','Di tích lịch sử gắn với những dấu mốc quan trọng của Việt Nam hiện đại.','A landmark associated with major moments in modern Vietnamese history.','135 Nam Kỳ Khởi Nghĩa, Quận 1, TP.HCM','135 Nam Ky Khoi Nghia, District 1, HCMC','Independence Palace Saigon'),
      _Place('Nhà thờ Đức Bà','Notre-Dame Cathedral Basilica','Công trình kiến trúc Pháp nổi bật; việc tham quan có thể thay đổi do trùng tu.','A prominent French-era landmark; access may change during restoration.','Công trường Công xã Paris, Quận 1','Paris Commune Square, District 1','Notre Dame Cathedral Saigon'),
      _Place('Bưu điện Trung tâm','Saigon Central Post Office','Công trình kiến trúc cổ nổi bật gần nhà thờ Đức Bà.','A historic architectural landmark near the cathedral.','2 Công xã Paris, Quận 1','2 Cong Xa Paris, District 1','Saigon Central Post Office'),
      _Place('Chợ Bến Thành','Ben Thanh Market','Khu chợ biểu tượng với quà lưu niệm và món ăn địa phương.','An iconic market for souvenirs and local food.','Lê Lợi, Quận 1, TP.HCM','Le Loi, District 1, HCMC','Ben Thanh Market'),
      _Place('Phố đi bộ Nguyễn Huệ','Nguyen Hue Walking Street','Đại lộ đi bộ trung tâm với các hoạt động buổi tối.','A central pedestrian boulevard with evening activity.','Đường Nguyễn Huệ, Quận 1','Nguyen Hue Street, District 1','Nguyen Hue walking street'),
      _Place('Landmark 81','Landmark 81','Tòa nhà cao tầng nổi bật với khu mua sắm và tầm nhìn thành phố.','A landmark skyscraper with shopping and city views.','720A Điện Biên Phủ, Bình Thạnh','720A Dien Bien Phu, Binh Thanh','Landmark 81 Saigon'),
      _Place('Bảo tàng Chứng tích Chiến tranh','War Remnants Museum','Bảo tàng giới thiệu tư liệu và hiện vật về chiến tranh Việt Nam.','A museum presenting documents and artefacts about the Vietnam War.','28 Võ Văn Tần, Quận 3','28 Vo Van Tan, District 3','War Remnants Museum'),
      _Place('Địa đạo Củ Chi','Cu Chi Tunnels','Hệ thống địa đạo lịch sử ở khu vực ngoại thành phía tây bắc.','A historic underground tunnel network in the north-western outskirts.','Huyện Củ Chi, TP.HCM','Cu Chi District, HCMC','Cu Chi Tunnels'),
      _Place('Chợ Bình Tây','Binh Tay Market','Khu chợ lâu đời mang nét kiến trúc và văn hóa Chợ Lớn.','A long-established market reflecting Cho Lon’s architecture and trading culture.','57A Tháp Mười, Quận 6','57A Thap Muoi, District 6','Binh Tay Market'),
      _Place('Bến Nhà Rồng','Nha Rong Wharf','Di tích bên sông Sài Gòn gắn với một dấu mốc lịch sử quan trọng.','A Saigon River historic site associated with a pivotal moment in history.','1 Nguyễn Tất Thành, Quận 4','1 Nguyen Tat Thanh, District 4','Nha Rong Wharf'),
    ]),
  _City(vi:'Phú Quốc',en:'Phu Quoc',photo:'Phu Quoc Sao beach turquoise water Vietnam',
    introVi:'Đảo ngọc nổi tiếng với biển xanh, bãi cát trắng, hoàng hôn và những trải nghiệm thiên nhiên.',
    introEn:'The Pearl Island, known for turquoise waters, white-sand beaches, sunsets and nature experiences.',
    color:Color(0xFF2499A5),places:[
      _Place('Bãi Sao','Sao Beach','Bãi biển nổi tiếng với cát trắng và làn nước xanh trong.','A famous beach with white sand and clear turquoise water.','An Thới, Phú Quốc','An Thoi, Phu Quoc','Sao Beach Phu Quoc'),
      _Place('Bãi Dài','Long Beach','Dải bờ biển dài nổi bật với cảnh hoàng hôn.','A long coastline known for sunsets.','Phía tây đảo Phú Quốc','Western Phu Quoc Island','Long Beach Phu Quoc sunset'),
      _Place('Grand World','Grand World Phu Quoc','Khu vui chơi với kiến trúc nhiều màu sắc, kênh nước và hoạt động buổi tối.','An entertainment area with colourful architecture, canals and evening activities.','Bãi Dài, Gành Dầu, Phú Quốc','Bai Dai, Ganh Dau, Phu Quoc','Grand World Phu Quoc'),
      _Place('Cáp treo Hòn Thơm','Hon Thom Cable Car','Tuyến cáp treo vượt biển với góc nhìn quần đảo An Thới.','A sea-crossing cable car with views of the An Thoi archipelago.','Ga An Thới, Phú Quốc','An Thoi Station, Phu Quoc','Hon Thom cable car'),
      _Place('Dinh Cậu','Dinh Cau Temple','Miếu ven biển gắn với đời sống tín ngưỡng của ngư dân.','A seaside shrine connected to local fishing communities.','Dương Đông, Phú Quốc','Duong Dong, Phu Quoc','Dinh Cau Phu Quoc'),
      _Place('Vườn quốc gia Phú Quốc','Phu Quoc National Park','Khu rừng tự nhiên rộng lớn với hệ sinh thái đa dạng.','A large natural forest area with diverse ecosystems.','Phía bắc đảo Phú Quốc','Northern Phu Quoc Island','Phu Quoc National Park'),
      _Place('Làng chài Hàm Ninh','Ham Ninh Fishing Village','Làng chài ven biển với khung cảnh mộc mạc và đời sống ngư dân.','A coastal fishing village with rustic scenery and local life.','Xã Hàm Ninh, Phú Quốc','Ham Ninh Commune, Phu Quoc','Ham Ninh fishing village'),
      _Place('Nhà tù Phú Quốc','Phu Quoc Prison','Di tích lịch sử lưu giữ tư liệu về một giai đoạn chiến tranh.','A historic site preserving accounts of wartime history.','Xã An Thới, Phú Quốc','An Thoi Commune, Phu Quoc','Phu Quoc Prison'),
      _Place('Suối Tranh','Tranh Stream','Khu sinh thái có suối và đường đi bộ giữa rừng.','An eco-area with a stream and forest walking paths.','Dương Tơ, Phú Quốc','Duong To, Phu Quoc','Tranh Stream Phu Quoc'),
      _Place('Sunset Town','Sunset Town','Khu phố ven biển với kiến trúc Địa Trung Hải và điểm ngắm hoàng hôn.','A seaside district with Mediterranean-inspired architecture and sunset viewpoints.','An Thới, Phú Quốc','An Thoi, Phu Quoc','Sunset Town Phu Quoc'),
    ]),
];
