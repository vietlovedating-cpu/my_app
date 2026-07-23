const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
});

const db = admin.firestore();
const now = admin.firestore.FieldValue.serverTimestamp();

const maleNames = [
  "Minh","Khoa","Huy","Duy","Long","Nam","Tony","Jason","Kevin","Andy",
  "Daniel","Brian","Henry","Tommy","Ryan","Ethan","Nathan","Alex","Victor","Peter",
  "Anthony","Ben","David","Leo","Michael","Chris","Steven","Jayden","Oliver","Aaron"
];

const femaleNames = [
  "Linh","Vy","Nhi","Mai","Trang","Annie","Jenny","Emily","Tina","Kelly",
  "Anna","Mia","Sophie","Linda","Natalie","Grace","Ivy","Hannah","Julie","Bella",
  "Chloe","Rachel","Cindy","Daisy","Helen","Nina","Ruby","Lucy","Vivian","Amy"
];

const suburbs = [
  ["Cabramatta, NSW, Australia", -33.8957, 150.9367],
  ["Bankstown, NSW, Australia", -33.9173, 151.0359],
  ["Parramatta, NSW, Australia", -33.8150, 151.0011],
  ["Liverpool, NSW, Australia", -33.9209, 150.9231],
  ["Hurstville, NSW, Australia", -33.9677, 151.1027],
];

function prompts() {
  return [
    {
      answer: "I value honesty and kindness.",
      answerEn: "I value honesty and kindness.",
      answerVi: "Tôi trân trọng sự chân thành và tử tế.",
      categoryEn: "Love",
      categoryKey: "love",
      categoryVi: "Tình yêu",
      promptId: "love_3",
      questionEn: "What I need most in love is...",
      questionVi: "Điều tôi cần nhất trong tình yêu là..."
    },
    {
      answer: "I enjoy peaceful and meaningful conversations.",
      answerEn: "I enjoy peaceful and meaningful conversations.",
      answerVi: "Tôi thích những cuộc trò chuyện nhẹ nhàng và ý nghĩa.",
      categoryEn: "Personality",
      categoryKey: "personality",
      categoryVi: "Tính cách",
      promptId: "personality_4",
      questionEn: "One thing I am proud of about myself is...",
      questionVi: "Một điều tôi tự hào về bản thân là..."
    },
    {
      answer: "Coffee and relaxing weekends.",
      answerEn: "Coffee and relaxing weekends.",
      answerVi: "Cà phê và cuối tuần thư giãn.",
      categoryEn: "Lifestyle",
      categoryKey: "lifestyle",
      categoryVi: "Lối sống",
      promptId: "lifestyle_5",
      questionEn: "One small joy in my day is...",
      questionVi: "Một niềm vui nhỏ mỗi ngày của tôi là..."
    },
    {
      answer: "I love simple and calm moments.",
      answerEn: "I love simple and calm moments.",
      answerVi: "Tôi thích những khoảnh khắc đơn giản và bình yên.",
      categoryEn: "Family",
      categoryKey: "family",
      categoryVi: "Gia đình",
      promptId: "family_5",
      questionEn: "I feel most at home when...",
      questionVi: "Tôi thấy ấm lòng nhất khi..."
    },
    {
      answer: "A peaceful future with someone loyal.",
      answerEn: "A peaceful future with someone loyal.",
      answerVi: "Một tương lai bình yên với người chân thành.",
      categoryEn: "Future",
      categoryKey: "future",
      categoryVi: "Tương lai",
      promptId: "future_4",
      questionEn: "One goal I am quietly working toward is...",
      questionVi: "Một mục tiêu tôi đang âm thầm theo đuổi là..."
    }
  ];
}

async function createProfile(index, gender) {

  const isMale = gender === "male";

  const uid = `demo_${gender}_${index}`;

  const suburb = suburbs[index % suburbs.length];

  const data = {
    uid,

    firstName: isMale
      ? maleNames[index % maleNames.length]
      : femaleNames[index % femaleNames.length],

    surname: "Tran",

    age: 18 + (index % 23),

    gender,
    genderLower: gender,

    datingPreference: isMale ? "female" : "male",
    datingPreferenceLower: isMale ? "female" : "male",

    occupation: isMale ? "finance" : "nurse",
    jobTitle: isMale ? "finance" : "nurse",

    annualIncome: "80_99k",

    residentStatus: "citizen",
    residentStatusLower: "citizen",

    relationshipGoal: "serious_relationship",

    relationshipGoals: ["serious_relationship"],

    religion: "buddhist",
    religionLower: "buddhist",

    selectedState: "New South Wales (NSW)",
    selectedStateKey: "nsw",
    selectedStateLower: "new south wales (nsw)",

    address: suburb[0],

    lat: suburb[1],
    lng: suburb[2],

    hideDistance: false,
    hideFromContacts: false,

    smoking: "no",
    smokingLower: "no",

    drinking: "socially",
    drinkingLower: "socially",

    height: isMale ? "178 cm" : "165 cm",

    isOnline: index % 2 === 0,

    profileCompleted: true,
    profilePromptsCompleted: true,

    onboardingStep: "done",

    isVip: false,
    vipUnlocked: false,

    membership: "free",
    plan: "free",

    mainPhotoUrl: "",
    photoUrls: [],
    photos: [],

    profilePrompts: prompts(),

    createdAt: now,
    updatedAt: now,
    lastSeen: now,
  };

  await db.collection("users").doc(uid).set(data);

  console.log("Created:", uid);
}

async function run() {

  for (let i = 0; i < 30; i++) {
    await createProfile(i, "male");
    await createProfile(i, "female");
  }

  console.log("DONE");
}

run();