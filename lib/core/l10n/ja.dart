/// Japanese (polite です/ます). Keys are the English source strings; see
/// lib/core/i18n.dart.
library;

const Map<String, String> ja = {
  // ---- navigation / shells
  'Shop': 'ショップ',
  'Orders': '注文',
  'Cart': 'カート',
  'My profile': 'プロフィール',
  'Sign out': 'ログアウト',
  'Back': '戻る',
  'Retry': '再試行',
  'Cancel': 'キャンセル',
  'View': '表示',
  'Loading…': '読み込み中…',
  'Nothing here yet.': 'まだ何もありません。',

  // ---- login / register / verify
  'Welcome back': 'おかえりなさい',
  'Order ahead.\nSkip the line.': '先に注文。\n行列なし。',
  'Campus food from your favorite {u} stalls, ready when you are. No deliveries, no waiting.':
      'お気に入りの{u}キャンパスの屋台の料理を、着いたらすぐ受け取れます。配達なし、待ち時間なし。',
  '{u} · order ahead, skip the line': '{u} · 先に注文、行列なし',
  'Order ahead': '事前注文',
  'Skip the line': '行列なし',
  'GCash & cash': 'GCash・現金',
  'Sign in to skip the line at your favorite stalls.': 'ログインして、お気に入りの屋台で並ばずに受け取りましょう。',
  'Email': 'メールアドレス',
  'Password': 'パスワード',
  'Forgot password?': 'パスワードをお忘れですか？',
  'Sign in': 'ログイン',
  "Don't have an account?": 'アカウントをお持ちでないですか？',
  'Create one': '新規登録',
  'Reset your password': 'パスワードの再設定',
  "We'll email you a link to set a new password.": '新しいパスワードを設定するリンクをメールでお送りします。',
  'Send link': 'リンクを送信',
  'Create your account': 'アカウント作成',
  'Student': '学生',
  'Stall owner': '屋台オーナー',
  'Staff': 'スタッフ',
  'Full name': '氏名',
  'Mobile number (optional)': '携帯電話番号（任意）',
  'Confirm': '確認',
  'Create account': 'アカウント作成',
  'Already have an account?': 'すでにアカウントをお持ちですか？',
  'How we use your data (privacy notice)': 'データの利用方法（プライバシーに関するお知らせ）',
  'Please agree to the ground rules to continue.': '続行するには基本ルールに同意してください。',
  'Verify your email': 'メールアドレスの確認',
  'This page continues by itself once you click the link.': 'リンクをクリックすると、このページは自動的に進みます。',
  "I've verified — continue": '確認しました — 続ける',
  'Use a different account': '別のアカウントを使う',
  'Not verified yet. Click the link in the email first.': 'まだ確認されていません。先にメール内のリンクをクリックしてください。',
  'Sent! Check your inbox (and spam folder).': '送信しました！受信トレイ（と迷惑メールフォルダ）をご確認ください。',
  'We sent a link to {email}. Open it to confirm this is your inbox, then come back here.':
      '{email} にリンクを送りました。リンクを開いてご自身のメールであることを確認し、ここに戻ってください。',
  'Resend email': 'メールを再送信',
  'Resend email ({s}s)': 'メールを再送信（{s}秒）',

  // ---- shop / stall
  "Stalls on campus — order ahead, pick up when it's ready.": 'キャンパスの屋台 — 先に注文して、できたら受け取り。',
  'Search stalls or food…': '屋台や料理を検索…',
  'Stalls on campus': 'キャンパスの屋台',
  'Good morning': 'おはようございます',
  'Lunch time': 'ランチタイム',
  'Good afternoon': 'こんにちは',
  'Hungry? Skip the line.': 'お腹すいた？並ばずにどうぞ。',
  '{n} open now': '{n}店 営業中',
  'Could not load stalls': '屋台を読み込めませんでした',
  'No stalls yet': 'まだ屋台がありません',
  'Check back soon — new stalls are added as they are verified.': 'またチェックしてください — 確認済みの新しい屋台が順次追加されます。',
  'Add favorite': 'お気に入りに追加',
  'Remove favorite': 'お気に入りから削除',
  'Open': '営業中',
  'Closed': '営業時間外',
  'New': 'NEW',
  'Back to shop': 'ショップに戻る',
  'Search this menu…': 'メニューを検索…',
  'Reviews': 'レビュー',
  'No reviews yet. Students can rate a stall after picking up.': 'まだレビューはありません。学生は受け取り後に屋台を評価できます。',
  'Add': '追加',
  '+ extras': '+ トッピング',
  'Free': '無料',
  'This stall is currently closed.': 'この屋台は現在営業時間外です。',
  'This stall is closed right now. You can browse the menu but cannot order.':
      '現在営業時間外です。メニューは見られますが、注文はできません。',
  '{name} added to cart': '{name}をカートに追加しました',
  'Only {n} left!': '残り{n}個！',
  '{n} in stock': '在庫{n}個',
  'Pickup: {place}': '受け取り場所：{place}',
  'Cart · {n}': 'カート · {n}',
  'Add · {price}': '追加 · {price}',
  '{price} · pick any extras': '{price} · トッピングを選択',
  'Ready in ~{m} min': '約{m}分でできあがり',
  'Ready in ~{m} min · {n} ahead': '約{m}分でできあがり · 前に{n}件',
  'Card full! Ask for {reward} at pickup.': 'スタンプカード完成！受け取り時に{reward}をもらってください。',
  '{have}/{need} stamps · {left} more for {reward}': 'スタンプ {have}/{need} · あと{left}個で{reward}',
  'Halal': 'ハラール',
  'Vegetarian': 'ベジタリアン',
  'Spicy': '辛口',
  'Bestseller': '人気',

  // ---- cart / checkout
  'Your cart': 'カート',
  'Your cart is empty': 'カートは空です',
  'Browse the stalls and add something tasty.': '屋台を見て、おいしいものを追加しましょう。',
  'Review your order before checkout.': 'お会計の前に注文内容をご確認ください。',
  'Clear cart': 'カートを空にする',
  'Cart cleared': 'カートを空にしました',
  'Subtotal': '小計',
  'Proceed to checkout': 'お会計へ進む',
  'Checkout': 'お会計',
  'Nothing to check out': 'お会計する商品がありません',
  'Pickup only — no deliveries on FoodRush.': '受け取りのみ — FoodRushは配達を行いません。',
  'Pickup at the stall': '屋台で受け取り',
  'Pickup time': '受け取り時間',
  'As soon as possible': 'できるだけ早く',
  'Today, {time}': '今日 {time}',
  'No later slots today. The stall closes soon.': '本日はこれ以降の時間枠がありません。まもなく閉店します。',
  'Payment method': 'お支払い方法',
  'GCash — pay now, upload receipt': 'GCash — 今すぐ支払い、領収書をアップロード',
  'Cash — pay at pickup': '現金 — 受け取り時に支払い',
  'Promo code': 'プロモコード',
  'Enter code': 'コードを入力',
  'Apply': '適用',
  'Note for the stall (optional)': '屋台へのメモ（任意）',
  'Place order — {total} via GCash': '注文する — GCashで{total}',
  'Place order — {total} cash at pickup': '注文する — 受け取り時に現金で{total}',

  // ---- tracking / orders
  'Order': '注文',
  'Order {n}': '注文 {n}',
  'Could not load order': '注文を読み込めませんでした',
  'QUEUE #': '番号',
  "Pickup: as soon as it's ready": '受け取り：できしだい',
  'Pickup: {time}': '受け取り：{time}',
  "Notify me when it's ready": 'できたら通知する',
  'Cash at pickup': '受け取り時に現金',
  'Paid via GCash': 'GCashで支払い済み',
  'GCash (not yet confirmed)': 'GCash（確認待ち）',
  'All my orders': 'すべての注文',
  'Order again': 'もう一度注文',
  'Order placed! Below is what happens next.': 'ご注文ありがとうございます！この後の流れは以下のとおりです。',
  'Pay with GCash': 'GCashで支払う',
  'Upload GCash receipt': 'GCashの領収書をアップロード',
  'Receipt submitted! The stall will verify it shortly.': '領収書を送信しました！まもなく屋台が確認します。',
  'Your rating': 'あなたの評価',
  'Comment (optional)': 'コメント（任意）',
  'Submit review': 'レビューを送信',
  'Saving…': '保存中…',
  'How was {stall}?': '{stall}はいかがでしたか？',
  'Thanks for rating {stall}!': '{stall}の評価ありがとうございます！',
  'This order was rejected by the stall.': 'この注文は屋台により断られました。',
  'This order was cancelled.': 'この注文はキャンセルされました。',
  'My orders': '注文履歴',
  'Track your pickups and review past orders.': '受け取り状況と過去の注文を確認できます。',
  'No orders yet': 'まだ注文はありません',
  'Your order history will appear here.': '注文履歴はここに表示されます。',
  'Active': '進行中',
  'Past': '過去',
  'No active orders. Hungry?': '進行中の注文はありません。お腹すいていませんか？',
  'Load older orders': '以前の注文をさらに表示',
  'Queue #{n}': '番号 #{n}',
  'Cancel order': '注文をキャンセル',
  'Cancel this order?': 'この注文をキャンセルしますか？',
  'This cannot be undone.': 'この操作は元に戻せません。',
  'Order cancelled': '注文をキャンセルしました',

  // ---- profile / install
  'Account details': 'アカウント情報',
  'Save changes': '変更を保存',
  'Profile saved.': 'プロフィールを保存しました。',
  'Send password reset link': 'パスワード再設定リンクを送信',
  'Appearance': '外観',
  'Language': '言語',
  'System': 'システム',
  'Light': 'ライト',
  'Dark': 'ダーク',
  'Delete my account': 'アカウントを削除',
  'Privacy notice': 'プライバシーに関するお知らせ',
  'Install FoodRush for one-tap ordering from your home screen.': 'FoodRushをインストールして、ホーム画面からワンタップで注文しましょう。',
  'Not now': '後で',
  'Install': 'インストール',
  'Got it': 'OK',

  // ---- alerts
  'Order #{n} is ready!': '#{n}番の注文ができあがりました！',
  'Pick it up at {stall}.': '{stall}で受け取ってください。',
  'Notifications on. Keep FoodRush open in a tab to get them.': '通知がオンになりました。通知を受け取るにはFoodRushをタブで開いたままにしてください。',
  'Notifications are blocked. Allow them in your browser settings.': '通知がブロックされています。ブラウザの設定で許可してください。',

  // ---- student number / password
  'Student number': '学籍番号',
  'Show password': 'パスワードを表示',
  'Hide password': 'パスワードを隠す',
  'Weak': '弱い',
  'Fair': '普通',
  'Good': '良い',
  'Strong': '強い',
  'Password strength: {level}': 'パスワードの強度：{level}',
  'Use at least 8 characters': '8文字以上にしてください',
  'Avoid common or repeated passwords': 'よくある・繰り返しのパスワードは避けてください',
  'Use 12 or more characters': '12文字以上にしましょう',
  'Mix upper and lower case': '大文字と小文字を混ぜましょう',
  'Add a number': '数字を加えましょう',
  'Add a symbol like ! or #': '! や # などの記号を加えましょう',

  // ---- verification email status
  'Sending a link to {email}…':
      '{email} にリンクを送信中…',
  'Sending…':
      '送信中…',
  'Sent at {time} from {sender}. Not in your inbox? Check Spam or Promotions.':
      '{time} に {sender} から送信しました。受信トレイにない場合は迷惑メールやプロモーションをご確認ください。',

  // ---- email links (expiry, counter, link page)
  'This link has expired. Send a new one.':
      'このリンクは期限切れです。新しいリンクを送信してください。',
  'Link expires in {time}':
      'リンクの有効期限まで {time}',
  'Email limit reached. Try again after {time}.':
      'メール送信の上限に達しました。{time} 以降にもう一度お試しください。',
  'Emails sent this hour: {n} of {max}':
      'この1時間に送信したメール：{n}/{max}',
  'Checking your link…':
      'リンクを確認しています…',
  'This link has expired':
      'このリンクは期限切れです',
  'Links work for {m} minutes. Open FoodRush and send a new one.':
      'リンクの有効期間は {m} 分です。FoodRushを開いて新しいリンクを送信してください。',
  'This link can’t be used':
      'このリンクは使用できません',
  'It was already used, or a newer email replaced it. Open FoodRush to continue.':
      'すでに使用されたか、新しいメールに置き換えられました。FoodRushを開いて続けてください。',
  'Email verified!':
      'メールアドレスを確認しました！',
  '{email} is confirmed. You can order now.':
      '{email} の確認が完了しました。注文できます。',
  'Choose a new password':
      '新しいパスワードを設定',
  'For {email}':
      '{email} 用',
  'Password changed':
      'パスワードを変更しました',
  'Sign in with your new password.':
      '新しいパスワードでログインしてください。',
  'Email change undone':
      'メールアドレスの変更を取り消しました',
  'Your sign-in email is {email} again. Consider changing your password too.':
      'ログイン用メールアドレスが {email} に戻りました。パスワードの変更もおすすめします。',
  'Something went wrong':
      '問題が発生しました',
  'Get a new link':
      '新しいリンクを取得',
  'Continue to FoodRush':
      'FoodRushへ進む',
  'New password':
      '新しいパスワード',
  'Save new password':
      '新しいパスワードを保存',

  // ---- profile photo
  'Profile photo':
      'プロフィール写真',
  'Stalls see this photo when you order, so they can hand your food to the right person.':
      '注文すると屋台にこの写真が表示され、正しい人に料理を渡せます。',
  'Add photo':
      '写真を追加',
  'Change photo':
      '写真を変更',
  'Remove photo':
      '写真を削除',
  'Photo updated.':
      '写真を更新しました。',
  'Photo removed.':
      '写真を削除しました。',
};
