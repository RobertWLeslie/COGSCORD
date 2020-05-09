require 'discogs-wrapper'
require 'discordrb'
require 'discordrb/webhooks'
require 'tmpdir'
require 'tempfile'

# Generates string from JSON object.
def generateReleaseString(release)
    description = ""
    release['basic_information']['formats'].each do |form|
        if(form['descriptions'])
            form['descriptions'].each do |desc|
                description += desc + " "
            end
        end
        if(form['name'])
            description += "#{form['name']}"
        end
        if(form['text'])
            description += ", #{form['text']} "
        end
        description+="\n"
    end
    return description
end

discogsUserTokenFile = File.new("DiscogsUserToken","r")
if discogsUserTokenFile
    discogsUserToken = discogsUserTokenFile.sysread(100000)
end

discordClientIDFile = File.new("DiscordClientID","r")
if discordClientIDFile
    discordClientID = discordClientIDFile.sysread(100000)
end

discordUserTokenFile = File.new("DiscordToken","r")
if discordUserTokenFile
    discordUserToken = discordUserTokenFile.sysread(10000)
end

bot = Discordrb::Commands::CommandBot.new(
    token: discordUserToken,
    client_id: discordClientID,
    prefix: '$'
)
wrapper = Discogs::Wrapper.new("Cogscord")

# Seach Authentication
auth_wrapper = Discogs::Wrapper.new(
    "COGSCORD",
    user_token: discogsUserToken
)

# $DevInfo
#   No parameters are passed, just responds wih developer's contact info
bot.command(:DevInfo) do |event|
    event.respond "@RWL1997"
end

# $ArtistInfo
#  Returns artist info
bot.command(:ArtistInfo) do |event|
    begin
        artistQuery = event.message.content.split(' ')[1..-1].join(' ')
        search = auth_wrapper.search(
            artistQuery,
            :per_page => 10,
            :type =>:artist
        )
        artist = wrapper.get_artist(search.results.first.id)
        event.respond artist.profile
    rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
        event.respond "uwu ewwow ocuwwed\n"
        event.respond e.message
    end
end

#$wantlist
#   Returns ten most recently added items to a user's want list
bot.command(:wantlist) do |event|
    begin
        user = event.message.content.split(' ')[1..-1].join(' ')
        wantlist =  wrapper.get_user_wantlist(user, {sort: "year", sort_order: 'desc', per_page: 10}).to_json()
        wants = JSON.parse(wantlist)

        event.channel.send_embed do |embed|
            embed.title = "#{user}'s 10 most recently wanted items:"
            
            if(!wants['message'])
                wants['wants'].each do |want|
                    embed.add_field(
                        name:"#{want['basic_information']['artists'][0]['name']} - #{want['basic_information']['title']}", 
                        value: generateReleaseString(want)
                    )
                end
            else
                embed.add_field(
                    name: "Oopsies!",
                    value: wants['message']
                )
            end
        end

    rescue Exception => e
        event.respond "\nuwu ewwow ocuwwed"
    end
end

#$collection 'user'
#   Returns ten most recently added items to a user's collection
bot.command(:collection) do |event|
    
    begin
        # Get collection, parse the JSON
        user = event.message.content.split(' ')[1..-1].join(' ')
        collection =  wrapper.get_user_collection(user, {sort: "added", sort_order: 'desc', per_page:10}).to_json()
        userCollection = JSON.parse(collection)
        
        event.channel.send_embed do |embed|
            embed.title = "#{user}'s 10 most recent items:"

            if(!userCollection['message'])
                userCollection['releases'].each do |item|

                    embed.add_field(
                        name: "#{item['basic_information']['artists'][0]['name']} - #{item['basic_information']['title']}",
                        value: generateReleaseString(item)
                    )
                end
            else
                embed.add_field(
                    name: "Oopsies!",
                    value: userCollection['message']
                )
            end
        end
    rescue Exception => e
        event.respond "Error occured: #{e}"
    end
end

#$inventory
#   Gets ten most recently listed items in inventory
bot.command(:inventory) do |event|
    user = event.message.content.split(' ')[1..-1].join(' ')
    inventory = wrapper.get_user_inventory(user, {sort: "listed", sort_order: 'desc', per_page: 10}).to_json()
    inv = JSON.parse(inventory)

    event.channel.send_embed do |embed|
        embed.title = "10 most recent listings"
        embed.colour = 0xbe915e
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: inv['listings'][0]['seller']['avatar_url'])
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: user , url: inv['listings'][0]['seller']['url'])

        if(!inv['message'])
            inv['listings'].each do |item|
                if(item['status']) == "For Sale"
                    embedName = "#{item['original_price']['formatted']}: #{item['release']['description']}  -  #{item['release']['format']}"
                    listing = "[(listing)](#{item['uri']})"
                    if(item['comments']!="")
                        listing = "\n" + listing
                    end
                    embedValue = "#{item['comments']}\nCondition: #{item['condition']}\nSleeve: #{item['sleeve_condition']} (#{listing})"
                    embed.add_field(
                        name: embedName,
                        value: embedValue
                    )
                end
            end
        else
            embed.add_field(
                name: "Oopsies!",
                value: userCollection['message']
            )
        end
    end
end

bot.command(:InputDebug) do |event|
    begin
        debugQueryArrayAfterCall = event.message.content.split(' ')[1..-1]
        debugQuery = debugQueryArrayAfterCall.join(' ')
        #puts event.message.content.split(' ')[1]
        #event.respond event.message.content.split(' ')[1]
        event.respond debugQuery
        puts debugQuery
    rescue
        event.respond "uwu ewwow ocuwwed"
        puts debugQuery
    end
end

bot.command(:InputDebug2) do |event|
    begin
        puts event.message.content
        event.respond event.message.content
    rescue
        event.respond "uwu ewwow ocuwwed"
    end
end


# $Help
#   No parameters passed, responds with list of commands
bot.command(:help) do |event|
    begin
        event.respond "List of Commands:
        $DevInfo - Show info about the developer
        $ArtistInfo 'Artist' - Show info about the artist
        $wantlist 'User' - Returns ten most recent items in user's wantlist
        $collection 'User' - Retiurns ten most recent items in users's collection
        "
    rescue
        event.respond "uwu ewwow ocuwwed"
    end
end

# This line must be last
bot.run