#!/usr/bin/env python
'''
pointless module to test with

'''
from ansible.module_utils.basic import AnsibleModule


def main():
    '''
    ansible another_rolemod module
    '''
    module = AnsibleModule(
        argument_spec=dict(
            something_to_say=dict(default=None, required=True, type='str'),
        ),
    )

    module.exit_json(
        msg=module.params["something_to_say"],
        changed=False
    )


if __name__ == "__main__":
    main()
