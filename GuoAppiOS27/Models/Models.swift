import Foundation

struct Drama: Identifiable, Codable, Hashable {
    let id: String
    let source: String
    let sourceID: String
    let title: String
    let description: String
    let cover: String
    let episodes: Int
    let category: String
    let vip: Bool?
    let heat: String?
    let views: String?
    let tags: [String]
    let releaseStatus: String?
    let score: String?

    enum CodingKeys: String, CodingKey {
        case id, source, title, description, cover, episodes, category
        case sourceID = "sourceId"
        case vip, heat, views, tags, releaseStatus, score
    }

    /// Memberwise initializer. Swift stops synthesizing this once a custom
    /// init(from:) exists, so declare it explicitly for demo/content creation.
    init(id: String, source: String, sourceID: String, title: String,
         description: String, cover: String, episodes: Int, category: String,
         vip: Bool? = nil, heat: String? = nil, views: String? = nil,
         tags: [String] = [], releaseStatus: String? = nil, score: String? = nil) {
        self.id = id
        self.source = source
        self.sourceID = sourceID
        self.title = title
        self.description = description
        self.cover = cover
        self.episodes = episodes
        self.category = category
        self.vip = vip
        self.heat = heat
        self.views = views
        self.tags = tags
        self.releaseStatus = releaseStatus
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        sourceID = try c.decodeIfPresent(String.self, forKey: .sourceID) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "未命名"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        cover = try c.decodeIfPresent(String.self, forKey: .cover) ?? ""
        episodes = try c.decodeIfPresent(Int.self, forKey: .episodes) ?? 0
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        vip = try c.decodeIfPresent(Bool.self, forKey: .vip)
        heat = try c.decodeIfPresent(String.self, forKey: .heat)
        views = try c.decodeIfPresent(String.self, forKey: .views)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        releaseStatus = try c.decodeIfPresent(String.self, forKey: .releaseStatus)
        score = try c.decodeIfPresent(String.self, forKey: .score)
    }

    // Stable identity across sources (mirrors Go's id + source pairing).
    var key: String { "\(source):\(id)" }
}

struct Chapter: Identifiable, Codable, Hashable {
    let id: String
    let source: String
    let title: String
    let videoURL: String
    let episode: Int
    let pageURL: String?
    let referer: String?
    let vertical: Bool?

    enum CodingKeys: String, CodingKey {
        case id, source, title, videoURL = "videoUrl"
        case pageURL = "pageUrl", referer, vertical
        case currentEpisode
    }

    /// Memberwise initializer (Swift suppresses the synthesized one once
    /// init(from:) is defined).
    init(id: String, source: String, title: String, videoURL: String,
         episode: Int, pageURL: String? = nil, referer: String? = nil,
         vertical: Bool? = nil) {
        self.id = id
        self.source = source
        self.title = title
        self.videoURL = videoURL
        self.episode = episode
        self.pageURL = pageURL
        self.referer = referer
        self.vertical = vertical
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        videoURL = try c.decodeIfPresent(String.self, forKey: .videoURL) ?? ""
        pageURL = try c.decodeIfPresent(String.self, forKey: .pageURL)
        referer = try c.decodeIfPresent(String.self, forKey: .referer)
        vertical = try c.decodeIfPresent(Bool.self, forKey: .vertical)
        // Episode number arrives as either a JSON number or string.
        if let n = try? c.decode(Int.self, forKey: .currentEpisode) {
            episode = n
        } else if let s = try? c.decode(String.self, forKey: .currentEpisode),
                  let n = Int(s.trimmingCharacters(in: .letters)) {
            episode = n
        } else {
            episode = 0
        }
    }

    /// Custom encode(to:) because the JSON key is `currentEpisode` while the
    /// property is `episode`; synthesis alone cannot pair them.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(source, forKey: .source)
        try c.encode(title, forKey: .title)
        try c.encode(videoURL, forKey: .videoURL)
        try c.encode(pageURL, forKey: .pageURL)
        try c.encode(referer, forKey: .referer)
        try c.encode(vertical, forKey: .vertical)
        try c.encode(episode, forKey: .currentEpisode)
    }
}

struct CatalogResult {
    var items: [Drama]
    var hasMore: Bool
    var page: Int
    var warning: String?
}

/// Hand-authored demo content, used only while no station module is installed.
/// Labeled in the UI so it is never mistaken for real source data.
enum DemoContent {
    static let sources = ["红果短剧", "韩小圈", "青空"]

    static func dramas(for category: String) -> [Drama] {
        let all = catalog
        if category == "推荐" || category.isEmpty { return all }
        return all.filter { $0.category == category }
    }

    static let catalog: [Drama] = [
        Drama(id: "demo-1", source: "红果短剧", sourceID: "demo-1", title: "长夜将明",
              description: "一场看似普通的事故，把六个陌生人困在同一栋楼里。随着真相层层剥开，每个人都藏着不愿示人的另一面。",
              cover: "p1", episodes: 24, category: "都市悬疑", vip: false, heat: "热播 TOP 1",
              views: "1.2亿", tags: ["悬疑", "都市", "反转"], releaseStatus: "已完结", score: "9.1"),
        Drama(id: "demo-2", source: "红果短剧", sourceID: "demo-2", title: "盛夏的回声",
              description: "多年后重逢，她已不再是当年那个跟在他身后的小女孩。",
              cover: "p3", episodes: 32, category: "甜宠", vip: false, heat: nil,
              views: "8652万", tags: ["甜宠", "校园", "治愈"], releaseStatus: "已完结", score: "8.7"),
        Drama(id: "demo-3", source: "红果短剧", sourceID: "demo-3", title: "我家陆总太粘人",
              description: "闪婚之后，那个传闻中冷淡的陆总，却恨不得二十四小时把她黏在身边。",
              cover: "p4", episodes: 60, category: "甜宠", vip: true, heat: "热播",
              views: "2.1亿", tags: ["先婚后爱", "霸总", "萌宝"], releaseStatus: "连载中", score: "8.4"),
        Drama(id: "demo-4", source: "红果短剧", sourceID: "demo-4", title: "山海食堂",
              description: "在山海交界的小镇，一家只在夜里营业的食堂，用一道菜治愈每个深夜来访的人。",
              cover: "p7", episodes: 20, category: "美食", vip: false, heat: nil,
              views: "3210万", tags: ["美食", "治愈", "慢生活"], releaseStatus: "已完结", score: "9.3"),
        Drama(id: "demo-5", source: "红果短剧", sourceID: "demo-5", title: "迷雾追凶",
              description: "一桩尘封十年的旧案被重新翻出，退休警官决定在生命倒计时结束前，亲手找到那个真凶。",
              cover: "p9", episodes: 28, category: "悬疑", vip: false, heat: "飙升",
              views: "7430万", tags: ["刑侦", "悬疑", "硬核"], releaseStatus: "已完结", score: "8.9"),
        Drama(id: "demo-6", source: "红果短剧", sourceID: "demo-6", title: "心跳越界",
              description: "一次意外，让两个世界观完全不同的人被迫共处。",
              cover: "p6", episodes: 36, category: "都市", vip: true, heat: nil,
              views: "5420万", tags: ["都市", "情感", "成长"], releaseStatus: "连载中", score: "8.2"),
        Drama(id: "demo-7", source: "红果短剧", sourceID: "demo-7", title: "归途有风",
              description: "离家十年后，他重新踏上那条熟悉的老街，风里还是小时候的味道。",
              cover: "p8", episodes: 24, category: "年代", vip: false, heat: nil,
              views: "1980万", tags: ["年代", "亲情"], releaseStatus: "已完结", score: "8.8"),
        Drama(id: "demo-8", source: "红果短剧", sourceID: "demo-8", title: "深海回响",
              description: "深海探测器传回一段无法解释的声呐信号，一支临时组建的队伍驶向无人知晓的海域。",
              cover: "p10", episodes: 30, category: "悬疑", vip: false, heat: nil,
              views: "6120万", tags: ["科幻", "悬疑", "探险"], releaseStatus: "已完结", score: "8.6")
    ]
}
