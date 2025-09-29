import { Clock, User, MessageSquare, Play } from "lucide-react";
import { Badge } from "@/components/ui/badge";
// import Image from "next/image"; // Next.js kullanıyorsan tercih et

type Article = {
  id: number;
  title: string;
  category: string;
  categoryColor: string; // consider a variant map instead of raw bg-*
  author: string;
  date: string;
  comments: number;
  views?: number;
  image: string;
  isVideo: boolean;
};

const PostsTile = () => {
  const tileNews: Article[] = [
    {
      id: 1,
      title: "Google hit with record EU fine over Shopping service",
      category: "Stories",
      categoryColor: "bg-red-500",
      author: "AF Themes",
      date: "July 18, 2018",
      comments: 0,
      views: 1240,
      image: "https://picsum.photos/300/200?1",
      isVideo: false
    },
    {
      id: 2,
      title: "Business booming for giant cargo planes",
      category: "Business",
      categoryColor: "bg-blue-500",
      author: "AF Themes",
      date: "July 18, 2018",
      comments: 3,
      views: 980,
      image: "https://picsum.photos/300/200?2",
      isVideo: false
    },
    {
      id: 3,
      title: "Trump-Putin: Your toolkit to help understand the story",
      category: "Business",
      categoryColor: "bg-blue-500",
      author: "AF Themes",
      date: "July 18, 2018",
      comments: 5,
      views: 2100,
      image: "https://picsum.photos/300/200?3",
      isVideo: false
    },
    {
      id: 4,
      title: "CQI-15 KAYNAK ÖZEL PROSES DEĞERLENDİRME",
      category: "Newsbeat",
      categoryColor: "bg-orange-500",
      author: "CQI Uzmanı",
      date: "Kasım 9, 2024",
      comments: 0,
      views: 365,
      image: "https://picsum.photos/300/200?4",
      isVideo: true
    }
  ];

  return (
    <section className="bg-background py-8">
      <div className="container mx-auto px-4">
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-foreground border-l-4 border-primary pl-4">
            Posts Tile
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {tileNews.map((article) => (
            <div key={article.id} className="group cursor-pointer">
              <div className="relative overflow-hidden rounded-lg mb-3">
                {/* <Image src={article.image} alt={article.title} width={300} height={200} className="w-full h-48 object-cover group-hover:scale-110 transition-transform duration-500" /> */}
                <img
                  src={article.image}
                  alt={article.title}
                  loading="lazy"
                  className="w-full h-48 object-cover group-hover:scale-110 transition-transform duration-500"
                />

                {article.isVideo && (
                  <div className="absolute inset-0 bg-black/20 flex items-center justify-center" aria-label="Play video">
                    <div className="w-12 h-12 bg-white/90 rounded-full flex items-center justify-center group-hover:scale-110 transition-transform">
                      <Play className="w-5 h-5 text-gray-800 ml-0.5" aria-hidden="true" />
                    </div>
                  </div>
                )}

                <div className="absolute top-3 left-3 flex gap-2">
                  <Badge className={`${article.categoryColor} text-white border-none text-xs`}>
                    {article.category}
                  </Badge>
                  {article.isVideo && (
                    <Badge className="bg-yellow-500 text-white border-none text-xs">
                      Video
                    </Badge>
                  )}
                </div>

                <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent h-1/2" />

                <div className="absolute bottom-3 left-3 right-3">
                  <h3 className="text-white font-bold text-sm leading-tight group-hover:text-yellow-300 transition-colors line-clamp-2">
                    {article.title}
                  </h3>
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex items-center gap-3 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <User className="w-3 h-3" aria-hidden="true" />
                    <span>{article.author}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Clock className="w-3 h-3" aria-hidden="true" />
                    <span>{article.date}</span>
                  </div>
                </div>

                <div className="flex items-center gap-3 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <MessageSquare className="w-3 h-3" aria-hidden="true" />
                    <span>{article.comments}</span>
                  </div>
                  {typeof article.views === "number" && (
                    <div className="flex items-center gap-1">
                      {/* Eye yerine views gösterilecekse ekleyebilirsin */}
                      {/* <Eye className="w-3 h-3" aria-hidden="true" /> */}
                      <span>{article.views} views</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="text-center mt-8">
          <button
            type="button"
            className="bg-primary text-primary-foreground px-8 py-3 rounded-lg font-medium hover:bg-primary/90 transition-colors"
          >
            Daha Fazla İçerik Görüntüle
          </button>
        </div>
      </div>
    </section>
  );
};

export default PostsTile;
