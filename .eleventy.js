const { DateTime } = require("luxon");

module.exports = function (eleventyConfig) {
  eleventyConfig.addGlobalData("computed", {
    wordCount: (data) => data.content.split(/\s+/).length,
  });

  eleventyConfig.addPassthroughCopy("./src/**/*/tailwind.css");
  eleventyConfig.addPassthroughCopy({'./src/_images': 'images'})

  eleventyConfig.addWatchTarget("./src/**/*.scss");
  eleventyConfig.addWatchTarget("./src/**/*/tailwind.css");
  eleventyConfig.addWatchTarget("tailwind.config.js");

  //* Collection to sort pages
  eleventyConfig.addCollection("page", function (collections) {
    return collections.getFilteredByTag("page").sort(function (a, b) {
      return a.data.order - b.data.order;
    });
  });

  eleventyConfig.addShortcode("currentDate", (date = DateTime.now()) => {
    return date;
  });

  eleventyConfig.addFilter("postDate", (dateObj) => {
    return DateTime.fromJSDate(dateObj).toLocaleString(DateTime.DATE_MED);
  });
  eleventyConfig.addFilter("dateStuff", (dateObj) => {
    return DateTime.fromJSDate(dateObj)
      .setLocale("uk")
      .toLocaleString(DateTime.MEDIUM);
  });

  eleventyConfig.addFilter("estimatedTime", (content) => {
    const wpm = 200;
    const estimate = content.split(/\s+/).length / wpm;
    if (estimate < 60) {
      return `1 minuto`;
    }
    if (estimate < 3600) {
      let minutes = Math.floor(estimate / 60);
      const remainingSeconds = estimate % 60;
      if (remainingSeconds > 30) minutes++;
      return `${minutes} minuto${minutes !== 1 ? "s" : ""}`;
    }
    if (estimate < 86400) {
      const hours = Math.floor(estimate / 3600);
      const remainingMinutes = Math.floor((estimate % 3600) / 60);
      return `${hours} hour${hours !== 1 ? "s" : ""}${
        remainingMinutes
          ? `, ${remainingMinutes} minuto${remainingMinutes !== 1 ? "s" : ""}`
          : ""
      }`;
    }
    const days = Math.floor(estimate / 86400);
    const remainingHours = Math.floor((estimate % 86400) / 3600);
    return `${days} day${days !== 1 ? "s" : ""}${
      remainingHours
        ? `, ${remainingHours} hora${remainingHours !== 1 ? "s" : ""}`
        : ""
    }`;
  });

  eleventyConfig.addCollection('posts', (collectionApi) => {
    return collectionApi.getFilteredByGlob('src//blog/*.md').reverse()
  })

  return {
    dir: {
      input: "src",
      data: "_data",
      includes: "_includes",
      layouts: "_layouts",
    },
  };
};
