class Course {
  final String id, title, category, contentUrl;

  Course({
    required this.id,
    required this.title,
    required this.category,
    required this.contentUrl,
  });

  factory Course.fromFirestore(Map<String, dynamic> data, String id) {
    return Course(
      id: id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      contentUrl: data['contentUrl'] ?? '',
    );
  }
}

class Question {
  final String question;
  final List<String> answers;
  final int correctIndex;

  Question({
    required this.question,
    required this.answers,
    required this.correctIndex,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'] ?? '',
      answers: List<String>.from(json['answers'] ?? []),
      correctIndex: json['correctIndex'] ?? 0,
    );
  }
}

class Lesson {
  final String id, title, content;
  final List<Question> questions;

  Lesson({
    required this.id,
    required this.title,
    required this.content,
    required this.questions,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}
