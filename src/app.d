module app;

import core.thread   : Thread;
import std.algorithm : filter, map, endsWith;
import std.array     : array, appender;
import std.conv      : to;
import std.exception : enforce;
import std.file      : SpanMode, readText, dirEntries, mkdir, rename;
import std.format    : formattedWrite;
import std.json      : parseJSON;
import std.path      : baseName, dirSeparator;
import std.regex     : ctRegex, match;


void main()
{
    auto paths = "stunas.json".readText().parseJSON().array.map!(path => path.str).array();

    foreach(path; paths)
    {
        path.checkDir().enforce();
        path.createBackupDir();
    }

    while(true)
    {
        foreach(path; paths)
        {
            path.backupReplays();
        }
        Thread.yield();
    }
}

bool checkDir(string path)
{
    foreach(entry; path.dirEntries(SpanMode.shallow))
    {
        if(entry.name.baseName() == "replay" && entry.isDir())
        {
            return true;
        }
    }

    return false;
}

void createBackupDir(string path)
{
    foreach(entry; path.dirEntries(SpanMode.shallow))
    {
        if(entry.name.baseName() == "replay_backup" && entry.isDir())
        {
            return;
        }
    }

    mkdir(path ~ dirSeparator ~ "replay_backup");
}

void backupReplays(string path)
{
    enum reg = ctRegex!r"^th\d+_\d\d\.rpy$";

    auto replays = dirEntries(path ~ dirSeparator ~ "replay", SpanMode.shallow)
                  .filter!(entry => entry.name.baseName().match(reg).captures.length && entry.isFile())()
                  .map!(entry => entry.name)
                  .array();

    auto nexts = path.getNextReplayNums(replays.length);

    foreach(i; 0 .. replays.length)
    {
        rename(replays[i], path ~ dirSeparator ~ "replay_backup" ~ dirSeparator ~ replays[i].baseName()[0 .. $ - "00.rpy".length] ~ nexts[i] ~ ".rpy");
    }
}

string[] getNextReplayNums(string path, size_t num)
{
    enum reg = ctRegex!r"^th\d+_(\d\d\d\d)\.rpy$";
    
    auto replayNums = dirEntries(path ~ dirSeparator ~ "replay_backup", SpanMode.shallow)
                 .map!(entry => entry.name.baseName().match(reg).captures[1].to!int())
                 .array();

    size_t max;

    foreach(replayNum; replayNums)
    {
        if(max < replayNum)
        {
            max = replayNum;
        }
    }

    string[] nextNums;

    foreach(_; 0 .. num)
    {
        ++max;
        auto appender = appender!string();
        appender.formattedWrite("%04d", max);
        nextNums ~= appender.data();
    }

    return nextNums;
}
