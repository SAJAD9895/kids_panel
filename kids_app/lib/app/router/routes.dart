/// Every route path in one place. Design ids in brackets (docs/design/README.md §5).
abstract final class Routes {
  static const splash = '/'; // K01
  static const welcome = '/welcome'; // K02
  static const setupChild = '/setup/child'; // K05
  static const setupBuddy = '/setup/buddy'; // K06
  static const setupGrownUp = '/setup/grown-up'; // K03 (sign-up + consents)
  static const setupFinish = '/setup/finish'; // creates the family
  static const signIn = '/sign-in'; // K04 start, P16 password
  static const verifyCode = '/sign-in/code'; // K04 code step

  static const whoIsPlaying = '/who'; // K35
  static const kids = '/kids'; // K07 home
  static const learn = '/kids/learn'; // K09 Learn: paths + courses
  static const watch = '/kids/watch'; // K12 (shelves for now)
  static const listen = '/kids/listen'; // K14 / K15 (shelves for now)
  static const me = '/kids/me'; // K17
  static const meBuddy = '/kids/me/buddy'; // K06 from Me ("change my buddy")
  static const rewards =
      '/kids/me/rewards'; // K16 rewards: stars, badges, goals, streak
  static const subjects = '/kids/subjects'; // K21 explore tiles
  static String subject(String key) => '/kids/subjects/$key'; // K08
  static String path(String id) => '/kids/paths/$id'; // learning path
  static const courses = '/kids/courses'; // course listing
  static String course(String id) => '/kids/courses/$id'; // K09 course
  static String lesson(String courseId, String lessonId) =>
      '/kids/courses/$courseId/lessons/$lessonId'; // K10
  static String activity(String id) =>
      '/kids/activities/$id'; // activity details
  static String play(String id) => '/kids/play/$id'; // K11 player (full screen)
  static String video(String id) => '/kids/watch/$id'; // K12 video details
  static String videoPlay(String id) =>
      '/kids/watch/$id/play'; // K13 video player (full screen)
  static String song(String id) =>
      '/kids/listen/songs/$id'; // K33 audio player (full screen)
  static String story(String id) =>
      '/kids/listen/stories/$id'; // K32 book reader (full screen)

  /// Where a card opens: videos → details, songs → the player, stories → the reader, others →
  /// the activity screen (course steps always go through the activity screen).
  static String open(String id, String type) => switch (type) {
    'video' => video(id),
    'song' || 'audiobook' => song(id),
    'story' => story(id),
    _ => activity(id),
  };

  static bool isKids(String path) => path == kids || path.startsWith('$kids/');
  static const gate = '/gate'; // K20

  static const parents = '/parents'; // P01
  static const children = '/parents/children'; // P02 list
  static const newChild = '/parents/children/new'; // K05 (F13)
  static const newChildBuddy = '/parents/children/new/buddy'; // K06 (F13)
  static String child(String id) => '/parents/children/$id'; // P02 edit
  static String childBuddy(String id) =>
      '/parents/children/$id/buddy'; // K06 picker
  static String childMedia(String id) =>
      '/parents/children/$id/media'; // P03 media controls + screen time
  static String childReport(String id) =>
      '/parents/children/$id/report'; // P04 progress report + analytics
  static const parentNotifications = '/parents/notifications'; // P11 inbox
  static const parentNotificationSettings =
      '/parents/notifications/settings'; // P11 preferences
  static const privacy = '/parents/privacy'; // P12 consents, export, deletion
  static const subscription = '/parents/subscription'; // P06
  static String childRewards(String id) =>
      '/parents/children/$id/rewards'; // P18 rewards, goals, how stars work

  static bool isParents(String path) =>
      path == parents || path.startsWith('$parents/');
}
