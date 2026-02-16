FROM ruby:3.3

# Set the working directory
WORKDIR /srv/jekyll

# Copy Gemfiles to install dependencies first (caching optimization)
COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN bundle install

# Copy the rest of the application
COPY . .

# Expose the default Jekyll port
EXPOSE 4000

# Default command (can be overridden by docker-compose)
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
