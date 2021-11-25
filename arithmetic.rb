#!/usr/bin/env ruby
# Multiply and Divide quiz

## DATABASE

require 'sqlite3'
db = SQLite3::Database.new('arithmetic.db')
db.results_as_hash = true
db.execute("create table if not exists answers (session text, n1 integer, n2 integer, operator text, answer integer, given integer, correct text, timing float)")

def last_saved_session(db)
  r = db.execute("select max(session) from answers")
  r[0][0]
end

def wrong(db, session)
  db.execute("select * from answers where session = ? and correct='false'", session)
end

def slow(db, session)
  db.execute("select * from answers where session = ? and correct='true' order by timing desc limit 3", session)
end

last_session = last_saved_session(db)
# these make an array of dbhashes, used before random questions, below
last_wrong = wrong(db, last_session)
last_slow = slow(db, last_session)

def question_from(h)
  return nil if h.nil?
  {operator: h['operator'], n1: h['n1'], n2: h['n2'], answer: h['answer']}
end

# get the next question to review from previous wrong or slow
# or nil if none
def review_question(last_wrong, last_slow)
  h = last_wrong.pop
  unless h.nil?
    return question_from(h)
  end
  h = last_slow.pop
  question_from(h)
end

## NUMBERS:

# range: 2 to 9
def rnum
  rand(8) + 2
end

def nums(operator)
  if operator == '÷'
    n2 = rnum
    n1 = rnum * n2
    right_answer = n1 / n2
  else
    n1 = rnum
    n2 = rnum
    right_answer = n1 * n2
  end
  [n1, n2, right_answer]
end

# questions given in this run, saved to make sure we don't duplicate
questions = []

# right_answers saved to find timing and errors
answers = []

# name this session by start time
session = Time.now().to_s

# Loop for this many questions
(1..50).each do |turn|

  # review wrong/slow from last session
  question = review_question(last_wrong, last_slow)

  if question.nil?
    # begin making a random question
    begin

      # randomly choose whether to present a divide or multiply problem
      operator = (rand(2) == 0) ? '÷' : '×'

      # get two random numbers to divide or multiply
      n1, n2, right_answer = nums(operator)

      # put them in a question format
      question = {operator: operator, n1: n1, n2: n2, answer: right_answer}

    # if that question was used in this round, pick a different one (back to "begin", above)
    end while questions.include?(question)
  end

  # if unique, save it so it won't be repeated in future questions this round
  questions << question

  # show the problem and start timing
  print "%d %s %d = " % [question[:n1], question[:operator], question[:n2]]
  time1 = Time.now()

  # get the answer and stop timing
  given = STDIN.gets.strip.to_i
  time2 = Time.now()

  # right or wrong?
  if question[:answer] == given
    correct = true
  else
    correct = false
  end
  timing = time2 - time1

  # save the answer
  db.execute("insert into answers values (?, ?, ?, ?, ?, ?, ?, ?)", session, question[:n1], question[:n2], question[:operator], question[:answer], given, correct.to_s, timing)

end

wrong(db, session).each do |q|
  puts "\nWRONG:"
  puts "%d %s %d = ___?" % [q['n1'], q['operator'], q['n2']]
  puts "right answer: %d" % q['answer']
  puts "(you said: %d)" % q['given']
end
