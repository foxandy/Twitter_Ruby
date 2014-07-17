##A Ruby script that explores various concepts in Twitter data mining, using resumes to an analytics graduate program as an example:
##- Parsing XML inputs
##- Compiling a list of potential Twitter user matches
##- Scoring users' contribution to a particular topic based on text analytics
##- Dealing with Twitter API Rate Limit

require 'rubygems'
require 'pry'
require 'twitter'
require 'CSV'
require 'xmlsimple'

class Twitter_user_search

## Interactive
#  def main_menu
#    configure
#	f = File.open("keywords.txt")
#	@keywords = f.read.split("\n")
#	f.close
#	userData = Array.new
#   puts "Enter your name"
#   name=gets
#   puts "Enter your email handle"
#   email_handle=gets
#   puts "Enter your university"
#   university = gets
#   puts "Enter your company"
#    company = gets

###########################################

## Parse resume input(.xml file), return an array
def resumeInputParse(resumeInput)
    # Parse resume input with gem "xmlsimple"
    xml = File.read resumeInput ;0
    data = XmlSimple.xml_in xml
    # Create and fill an array with hashes w/ name, university and email as keys
    input = Array.new
    array_length = data["Worksheet"][0]["Table"][0]["Row"].length
    (1..array_length-1).each do |i|
        twitter = {}
        twitter[:name] = data["Worksheet"][0]["Table"][0]["Row"][i]["Cell"][0]["Data"][0]["content"]
        # check if the content for university or email is missing
        # o/w fill in with a value of nil
        if data["Worksheet"][0]["Table"][0]["Row"][i]["Cell"][1].length ==2
            twitter[:university] = data["Worksheet"][0]["Table"][0]["Row"][i]["Cell"][1]["Data"][0]["content"]
            else
            twitter[:university] = ""
        end
        if data["Worksheet"][0]["Table"][0]["Row"][i]["Cell"][2].length ==2
            twitter[:email] = data["Worksheet"][0]["Table"][0]["Row"][i]["Cell"][2]["Data"][0]["content"]
            else
            twitter[:email] = ""
        end
        input << twitter
    end
    return input
end

## A method to help extract the handle from an email address
def emailHandle(email)
    if email == ""
        emailHandle = ""
        else
        emailHandle = email.sub /([a-z0-9._%+-]*)(@)([a-z0-9.-]*)/,'\1'
    end
    return emailHandle
end

## Get Twitter configuration - enter own Twitter keys and tokens
def configure
    @client = Twitter.configure do |config|
      config.consumer_key = ""
      config.consumer_secret = ""
      config.oauth_token = ""
      config.oauth_token_secret = ""
    end
end
=begin
## Collect Twitter data of a particular user
def twitter_collect(actual_name)
    userMaster = Array.new
	counter = 0
	potential_users=@client.user_search(actual_name, count:20)
	begin
		potential_users.each do |p|
			tempTweets = Array.new
			tempFollowing = Array.new
			if (p.protected.to_s != "true")
				tempName = p.attrs[:name].to_s
				tempHandle = p.attrs[:screen_name].to_s
				puts "Collecting Twitter data for " + tempHandle
				myTweets = @client.user_timeline(p, count:200)
				myTweets.each do |t|
					tempTweets.push(t.attrs[:text].to_s)
				end
				myFollowing = @client.friends(p, count:200)
				myFollowing.each do |f|
					tempFollowing.push(f.attrs[:screen_name].to_s)
				end
				tempHash = {actualName: actual_name, twitterName: tempName, twitterHandle: tempHandle, tweets: tempTweets, following: tempFollowing}
				userMaster<<tempHash
				counter = counter+1
			end
		end
    #    rescue Twitter::Error::TooManyRequests => error
    #    puts "Twitter @Rate Limit Reached.  Stopped collecting data after " + counter.to_s + " users."
	end
	return userMaster
end
=end
=begin
def checkRate(flag)
    if @rate < 150 then
		if flag == 0 then
			@rate+=1
		else
			@rate+=1/150.0
		end
	else
		puts "Twitter Rate Limit reached.  Sleeping for 15 minutes."
		sleep(15*60)
		@rate = 0.0
    end
end
=end

##Collects Twitter data for all potential users that may be a match
def twitter_collect(actual_name)
    userMaster = Array.new
    counter = 0
    #checkRate(0)
    begin
		potential_users=@client.user_search(actual_name, count:5)
    rescue Twitter::Error::TooManyRequests => error
        puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
		sleep(15*60)
		retry
    end
        potential_users.each do |p|
            tempTweets = Array.new
            tempFollowing = Array.new
            if (p.protected.to_s != "true")
                #checkRate(0)
                begin
					tempName = p.attrs[:name].to_s
				rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					retry
				end
                #checkRate(0)
				begin
					tempHandle = p.attrs[:screen_name].to_s
                rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					retry
				end
				
                puts "Collecting Twitter data for " + tempHandle
                #checkRate(1)
				begin
					myTweets = @client.user_timeline(p, count:200)
				rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					retry
				end
                begin
					myTweets.each do |t|
						tempTweets.push(t.attrs[:text].to_s)
					end
				rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					tempTweets = Array.new
					retry
				end
	
                #checkRate(1)
                begin
					myFollowing = @client.following(p, count:200)
				rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					retry
				end					
				
				begin
					myFollowing.each do |f|
						tempFollowing.push(f.attrs[:screen_name].to_s)
					end
                rescue Twitter::Error::TooManyRequests => error
					puts "Twitter Rate Limit Reached.  Sleeping for 15 minutes."
					sleep(15*60)
					tempFollowing = Array.new
					retry
				end
                tempHash = {actualName: actual_name, twitterName: tempName, twitterHandle: tempHandle, tweets: tempTweets, following: tempFollowing}
                userMaster << tempHash
                counter = counter+1
            end
        end
    #rescue Twitter::Error::TooManyRequests => error
        #puts "Twitter Rate Limit Reached.  Stopped collecting data after " + counter.to_s + " users."
    #end
    return userMaster
  end

## Match score - score / 100
def match(user, university, *args)
    
    # Analytics score - highest predictor - normalised to /50
    analyticsScore = analytics(user)
    
    # Tweets about university, company (normalised to /40)
    tweets_mine(user,university)
    infoScore = [@tweet_idinfo,2].min + [@friend_idinfo,2].min
    puts "There are #{@tweet_idinfo} university matches on the tweets"
	puts "there are #{@friend_idinfo} university matches on the friends"
    
    # Levenshtein distance (normalised to /10 - i.e. a tie-breaker, since we already have name)
    levDist = 10
    args.each do |a|
        ld = levenshtein(user[:twitterHandle].strip,a.strip)
        levDist = ld if ld < levDist
    end
    levScore = 10-[levDist,10].min
    puts "The Levenshtein distance is #{levScore}"
    
    return (analyticsScore * 30.0/20.0) + (infoScore * 40.0/4.0) + (levScore * 30.0/10.0)
end

## Analytics score
def analytics(user)
    
    # Keyword match tweets
    tweets_mine(user)
    puts "There are #{@tweet_keywords} keyword matches on the tweets"
    
    # Keyword match followers
    #followers_mine(user)
	@follower_words = 0
    #puts "There are #{@follower_words} keyword matches on the followers"
    
    # Keyword match friends
    friends_mine(user)
    puts "There are #{@friend_words} keyword matches on the friends"
    
    return [(@tweet_keywords + @follower_words + @friend_words),20].min
end

def fix(text)
    text2 = text.upcase
    array = text2.split(' ')
    array.each do |word|
        if word.length < 4 or word == "UNIVERSITY" or word == "COLLEGE" or word == "SCHOOL" then
            array.delete(word)
        end
    end
	str = " "
    array.each do |word|
        str = str + word + " "
    end
    str = str.strip

    return str
end

## Match Tweets related to analytics
def tweets_mine(user, *args)
    tweets=user[:tweets]
	@tweet_keywords = 0
    @tweet_idinfo = 0
    tweets.each do |t|
        str=t
        if args.empty? then
            @keywords.each do |k|
                pattern=str[k]
                if pattern!=nil
                    @tweet_keywords+=1
                end
            end
            else
            args.each do |a|
                a_fixed = fix(a)
                pattern=str[a_fixed]
                if pattern!=nil
                    @tweet_idinfo+=1
                end
            end
        end
    end
end

##Match Twitter friends related to analytics
def friends_mine(user, *args)
    friends=user[:following]
    @friend_words = 0
	@friend_idinfo = 0
    friends.each do |f|
        str=f
		if args.empty? then
			@keywords.each do |k|
                pattern=str[k]
                if pattern!=nil
                    @friend_words+=1
                    puts "Match: " + str
                    #scrnames = @client.friends("atockar",count:5).collect{|x| x.screen_name}.to_s
                end
			end
            else
			args.each do |a|
				a_fixed = fix(a)
                pattern=str[a_fixed]
				if pattern!=nil
					@friend_idinfo+=1
					puts "Match: " + str
				end
			end
		end
    end
end

## Given two words, returns edit distance
def levenshtein(s, t)           # issue - should be 0 if equal
    m = s.length
    n = t.length
    return m if n == 0
    return n if m == 0
    
    d = Array.new(m+1) {Array.new(n+1)}
    
    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
        (1..m).each do |i|
            d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
            d[i-1][j-1]       # no operation required
            else
            [ d[i-1][j]+1,    # deletion
            d[i][j-1]+1,    # insertion
            d[i-1][j-1]+1,  # substitution
            ].min
        end
    end
end
d[m][n]
end

## Write Scores into a .csv file
def readWrite(userData)
    existing = Array.new
    CSV.foreach("scores.csv") do |row|
        existing.push(row)
    end
    b = userData.map { |elem| elem.split(";") }
    CSV.open("scores.csv", "w") do |csv|
        existing.each do |e|
            csv << e
        end
        b.each { |row| csv << row }
    end
end


## Uses all those methods to get scores
def getScores
    configure
    f = File.open("keywords.txt")
    	@keywords = f.read.split("\n")
    	f.close
    	userData = Array.new
	input=Array.new
	input=resumeInputParse("master_twitter.xml")
    @rate = 0.0
    (2..3).each do |i|
        #take the input
        name = input[i][:name]
        university = input[i][:university]
        email = input[i][:email]
        email_handle = emailHandle(email)
        names=name.split('_')
        last_name=names[0]
        first_name=names.last 
        pos_handle1=first_name+last_name
        pos_handle2=last_name+first_name
        pos_handle3=first_name[0]+last_name
        pos_handle3=first_name+last_name[0]
        #start match
        users=twitter_collect("adrianmontero88")
        len=users.length
        flag=false
        if len==0
            puts "The user does not have a Twitter account"
            score=0
            
            else
            users.each do |u|
                puts u[:twitterHandle]
                matchScore = match(u,university,email_handle, pos_handle1,pos_handle2,pos_handle3)
                puts "Match score is " + matchScore.to_s + "/100"
                
                analyticsScore = analytics(u)
                puts "Analytics score is " + (analyticsScore*100.0/20.0).to_s + "/100"
                userData.push(name.strip+";"+u[:twitterHandle]+";"+matchScore.to_s+";"+analyticsScore.to_s)
            end
        end
        readWrite(userData)
    end
 end
end

user1 = Twitter_user_search.new
user1.getScores
