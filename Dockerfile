FROM ruby:3.2.2

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

RUN mkdir /quimicenter
WORKDIR /quimicenter

COPY Gemfile Gemfile.lock /quimicenter/

RUN bundle install

COPY . /quimicenter

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]