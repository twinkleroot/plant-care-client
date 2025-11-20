import 'package:flutter/material.dart';

class GuideDialog extends StatefulWidget {
  const GuideDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const GuideDialog(),
    );
  }

  @override
  State<GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<GuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 가이드 데이터 (이미지는 assets에 guide_1.png 등으로 저장되어 있다고 가정)
  final List<Map<String, String>> _guides = [
    {
      'image': 'assets/images/guide_1.jpeg',
      'title': '내 화초 등록하기',
      'content': '이름, 날짜만 입력하면 끝!\n복잡한 정보 없이 간편하게 등록하세요.',
    },
    {
      'image': 'assets/images/guide_2.jpeg',
      'title': '물주기 알림 받기',
      'content': '매일 아침 9시, 물 줘야 할 식물을 알려드려요.\n더 이상 깜빡하지 마세요.',
    },
    {
      'image': 'assets/images/guide_3.jpeg',
      'title': '한눈에 관리하기',
      'content': '물 준 날, 분갈이 날짜를 한눈에 보고\n물주기 버튼 한 번으로 기록해 보세요.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 500, // 이미지 비율에 맞춰 높이 약간 조정
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 닫기 버튼
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // 페이지 뷰
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _guides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final guide = _guides[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 이미지 영역 (실제 이미지)
                      Container(
                        height: 250,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.transparent, // 배경 투명
                          borderRadius: BorderRadius.circular(12),
                        ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              guide['image']!,
                              fit: BoxFit.contain, // 비율 유지하며 표시
                              errorBuilder: (context, error, stackTrace) {
                                // 이미지 로드 실패 시 대체 아이콘
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                );
                              },
                            ),
                          )
                      ),
                      Text(
                        guide['title']!,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        guide['content']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                    ],
                  );
                },
              ),
            ),
            // 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_guides.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.green : Colors.grey[300],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}