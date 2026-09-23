module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // qoomon conventional-commits adds `ops` (CI/CD, infra, deployment)
    // which @commitlint/config-conventional does not include by default.
    'type-enum': [
      2,
      'always',
      [
        'build',
        'chore',
        'ci',
        'docs',
        'feat',
        'fix',
        'ops',
        'perf',
        'refactor',
        'revert',
        'style',
        'test',
      ],
    ],
  },
}
