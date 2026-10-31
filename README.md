# fivelog

Logs what happens on your server to MariaDB so staff can search it later, and posts the parts you pick to Discord.

Kills, damage, chat, money, items, spawned vehicles, joins and leaves. Every line has who did it, who it was done to, when and where.

## What it logs

| Kind | Example |
|---|---|
| Deaths | `Tommy Reyes killed Jade Ortiz with a Combat pistol from 9m, headshot` |
| Damage | `Tommy Reyes hit Marcus Vale 3 times with a Combat pistol for 68 damage, 1 to the head, 14m away` |
| Chat | `Marcus Vale: anyone near legion? need a tow` |
| Money | `Leo Chen got $25,000 bank (Sold vehicle)` |
| Items | `Kira Novak gave 2x Lockpick to Dex Moreno`, `Nina Park took 1x Pistol from stash police_armory` |
| Vehicles | `Ava Brooks spawned a Sultan RS (82KQL110)` |
| Joins | `Bobby Lane left after 1h 12m: Exiting` |
| Resources | `qb-garages started` |

- **Damage** hits from one player with one weapon are folded into a single line every few seconds, so a firefight doesn't turn into hundreds of rows.
- **Money** works with Qbox, QBCore and ESX.
- **Items** need ox_inventory. Giving, dropping, picking up, stashes, trunks, gloveboxes and shop purchases are logged. Moving things around your own inventory isn't.
- **Vehicles** are the ones spawned by scripts: garages, admin menus, and cheat menus. Traffic and parked cars aren't logged.
- Commands aren't logged. The game runs them on the player's side and the server never sees them.

## With the others

- **[fivepanel](https://github.com/1amZach/fivepanel):** a Logs page you can filter by kind, day and text, with new lines appearing live. Every player profile shows their recent activity.
- **[fivecord](https://github.com/1amZach/fivecord):** Discord posts go to fivecord's log channels. fivecord already posts joins, deaths, chat and resources, so fivelog leaves those to it.
- **[warden](https://github.com/1amZach/warden):** kick and ban logs show the player's last few actions.

## Install

Needs [oxmysql](https://github.com/overextended/oxmysql).

1. Drop `fivelog` into your resources and add to `server.cfg` after oxmysql and your framework:

   ```
   ensure fivelog
   ```

2. The `fivelog` table is made on first start. If your database user can't create tables, run `sql/fivelog.sql` yourself.

3. For Discord with fivecord, add channels for the new kinds to fivecord's `Config.logs`. Anything without one goes to its default channel.

   ```lua
   money = '123456789012345678',
   items = '123456789012345678',
   vehicles = '123456789012345678',
   ```

   Without fivecord, put webhook URLs in `Config.discord` instead.

## Config

`config.lua`:

| | |
|---|---|
| `Config.keepDays` | How long logs are kept. 30 by default |
| `Config.keep` | Shorter for some kinds. Damage 7 days, chat 14 |
| `Config.record` | Turn a kind off |
| `Config.discord` | Where each kind is posted: `false`, a webhook URL, or a fivecord channel name |
| `Config.moneyPostMin` | Smaller money changes are kept but not posted. $10,000 by default |
| `Config.postEvery` | Seconds between Discord posts. Lines in between are sent together |
| `Config.damageWindow` | Seconds of hits folded into one damage line |
| `Config.recent` | Lines kept in memory per player for `recent` |

## For other resources

```lua
-- your own log lines, searchable like the rest
exports.fivelog:add('robbery', source, 'Started the Fleeca robbery at Legion', { bank = 'legion' })

-- with someone on the other end
exports.fivelog:add('trade', source, 'Sold a car to Leo Chen', nil, buyerSource)

-- the last lines involving a player, newest last
local lines = exports.fivelog:recent(source, 10)
```

Searching the database is done over events, since an export can't wait for it:

```lua
TriggerEvent('fivelog:query', 'myresource:1', { kind = 'deaths', player = 'license:abc', q = 'headshot', limit = 50 })

AddEventHandler('fivelog:query:done', function(id, ok, rows)
    if id ~= 'myresource:1' then return end
end)
```

Every new line is also sent as the server event `fivelog:entry`.

## Testing

```
lua5.4 test/run.lua
```

Runs the server side against a fake FiveM server and database.

## Support

Made by **IamZach**. Questions, bugs or ideas: [discord.gg/agn](https://discord.gg/agn)

## License

MIT
