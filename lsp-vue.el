;;; lsp-vue.el --- A lsp-mode client for Vue3 -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 sdvcrx
;;
;; Author: JadeStrong <https://github.com/jadestrong>
;; Author: sdvcrx <https://github.com/sdvcrx>
;; Maintainer: sdvcrx <me@sdvcrx.com>
;; Created: November 08, 2021
;; Modified: July 12, 2025
;; Version: 3.0.0
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex tools unix vc wp
;; Homepage: https://github.com/sdvcrx/lsp-vue
;; Package-Requires: ((emacs "29.2"))
;;
;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;
;;; Commentary:
;;
;; provide the connection to lsp-mode and vue language server
;;
;;; Code:
(require 'lsp-mode)
(require 'dash)

(defgroup lsp-vue nil
  "Lsp support for vue3."
  :group 'lsp-mode
  :link '(url-link "https://github.com/vuejs/language-tools")
  :package-version '(lsp-mode . "9.0.0"))

(defcustom lsp-vue-activate-languages '("vue")
  "List of languages to enable vtsls for."
  :group 'lsp-vue
  :package-version '(lsp-mode . "9.0.0")
  :type '(repeat string))

(lsp-dependency 'vue-language-server
                '(:npm :package "@vue/language-server" :path "vue-language-server"))

(defun lsp-vue--send-notify (workspace method params)
  "Send notification to WORKSPACE with METHOD PARAMS."
  (with-lsp-workspace workspace
    (let ((body (lsp--make-notification method params)))
      (lsp--send-no-wait body
        (lsp--workspace-proc lsp--cur-workspace)))))

(defun lsp-vue--tsserver-request-handler (vue-workspace params)
  "Handles `tsserver/request` notification from VUE-WORKSPACE.
And forwarding PARAMS to the `vtsls` LSP server.

Reference:
- https://github.com/vuejs/language-tools/discussions/5456
- https://github.com/vuejs/language-tools/wiki/Neovim#configuration"
  (if-let ((vtsls-workspace (lsp-find-workspace 'vtsls nil)))
    (with-lsp-workspace vtsls-workspace
      (-let [[[id command payload]] params]
        (lsp-request-async
          "workspace/executeCommand"
          (list :command "typescript.tsserverRequest"
            :arguments (vector command payload))
          ;; response callback
          (lambda (response)
            (let ((body (lsp-get response :body)))
              (lsp-vue--send-notify vue-workspace "tsserver/response" (vector (vector id body)))))
          ;; error callback
          :error-handler (lambda (error-response)
                           (lsp--warn "tsserver/request async error: %S" error-response)))))
    (lsp--error "[lsp-vue] Could not found `vtsls` lsp client, lsp-vue would not work without it")))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection
                   (lambda ()
                     `(,(lsp-package-path 'vue-language-server) "--stdio")))
  :activation-fn (lambda (_file-name _mode)
                   (-contains? lsp-vue-activate-languages (lsp-buffer-language)))
  :priority 1
  :multi-root nil
  :add-on? t  ;; work with vtsls
  :server-id 'vue-ls
  :initialization-options (lambda () (ht-merge (lsp-configuration-section "vue")))
  :notification-handlers (ht ("tsserver/request" #'lsp-vue--tsserver-request-handler))
  :initialized-fn (lambda (workspace)
                    (with-lsp-workspace workspace
                      (lsp--server-register-capability
                       (lsp-make-registration
                        :id "random-id"
                        :method "workspace/didChangeWatchedFiles"
                        :register-options? (lsp-make-did-change-watched-files-registration-options
                                            :watchers
                                            `[
                                               ,(lsp-make-file-system-watcher :glob-pattern "**/*.vue")
                                              ])))))
  :download-server-fn (lambda (_client callback error-callback _update?)
                        (lsp-package-ensure 'vue-language-server
                                            callback error-callback))))

(provide 'lsp-vue)
;;; lsp-vue.el ends here
