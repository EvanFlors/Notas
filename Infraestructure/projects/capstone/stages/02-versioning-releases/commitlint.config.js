/**
 * Conventional Commits ruleset shared by husky (commit-msg hook) and the
 * `commitlint` CI job. Keep the type list in sync with
 * release-please-config.json → changelog-sections.
 */
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'perf',
        'refactor',
        'docs',
        'test',
        'build',
        'ci',
        'chore',
        'revert',
        'deps',
      ],
    ],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [1, 'always', 100],
    'footer-leading-blank': [2, 'always'],
  },
};
