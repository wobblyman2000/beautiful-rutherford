#include <iostream>
#include <string>
#include <filesystem>
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>

namespace fs = std::filesystem;

void copyAndTag(const std::string &src, const std::string &dest,
                const std::string &title, const std::string &artist,
                const std::string &album, const std::string &genre,
                int year, int trackNo, int discNo, const std::string &albumType) {
    fs::path destPath(dest);
    fs::create_directories(destPath.parent_path());
    
    if (fs::exists(dest)) {
        fs::remove(dest);
    }
    fs::copy_file(src, dest);
    
    TagLib::FileRef f(dest.c_str());
    if (!f.isNull() && f.tag()) {
        f.tag()->setTitle(title);
        f.tag()->setArtist(artist);
        f.tag()->setAlbum(album);
        f.tag()->setGenre(genre);
        f.tag()->setYear(year);
        f.tag()->setTrack(trackNo);
        
        TagLib::PropertyMap properties = f.file()->properties();
        properties["DISCNUMBER"] = TagLib::StringList(std::to_string(discNo));
        properties["ALBUMTYPE"] = TagLib::StringList(albumType);
        f.file()->setProperties(properties);
        
        f.file()->save();
        std::cout << "Tagged: " << dest << " (" << albumType << ")\n";
    } else {
        std::cerr << "Failed to tag: " << dest << "\n";
    }
}

int main() {
    std::string templateMp3 = "mock_music_library/The Beatles - Help!/01 - Help!.mp3";
    if (!fs::exists(templateMp3)) {
        std::cerr << "Template file not found at: " << templateMp3 << "\n";
        return 1;
    }
    
    copyAndTag(templateMp3, "mock_music_library/ABBA - Arrival/01 - Dancing Queen.mp3",
               "Dancing Queen", "ABBA", "Arrival", "Pop, Disco", 1976, 1, 1, "Studio");
    copyAndTag(templateMp3, "mock_music_library/ABBA - Arrival/02 - Knowing Me, Knowing You.mp3",
               "Knowing Me, Knowing You", "ABBA", "Arrival", "Pop, Disco", 1976, 2, 1, "Studio");

    copyAndTag(templateMp3, "mock_music_library/ABBA - Waterloo/01 - Waterloo (Single).mp3",
               "Waterloo (Single)", "ABBA", "Waterloo", "Pop", 1974, 1, 1, "Single");

    copyAndTag(templateMp3, "mock_music_library/ABBA - Greatest Hits/01 - SOS.mp3",
               "SOS", "ABBA", "Greatest Hits", "Pop", 1975, 1, 1, "Compilation");
    copyAndTag(templateMp3, "mock_music_library/ABBA - Greatest Hits/02 - Mamma Mia.mp3",
               "Mamma Mia", "ABBA", "Greatest Hits", "Pop", 1975, 2, 1, "Compilation");

    copyAndTag(templateMp3, "mock_music_library/ABBA - Live in Wembley/01 - Take a Chance on Me (Live).mp3",
               "Take a Chance on Me (Live)", "ABBA", "Live in Wembley", "Pop, Live", 2014, 1, 1, "Live");

    copyAndTag(templateMp3, "mock_music_library/Various Artists - 70s Hits/01 - Stayin' Alive.mp3",
               "Stayin' Alive", "Bee Gees", "70s Hits", "Disco", 1977, 1, 1, "Compilation");
    copyAndTag(templateMp3, "mock_music_library/Various Artists - 70s Hits/02 - Gimme! Gimme! Gimme!.mp3",
               "Gimme! Gimme! Gimme!", "ABBA", "70s Hits", "Pop, Disco", 1979, 2, 1, "Compilation");

    return 0;
}
